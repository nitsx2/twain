from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import require_role
from app.db import get_db
from app.models import Chat, ChatMessage, Consultation, PatientProfile, User

router = APIRouter(prefix="/api/doctor", tags=["doctor"])


class FetchByCodeIn(BaseModel):
    patient_code: int = Field(ge=1000, le=9999)


class FetchByCodeOut(BaseModel):
    consultation_id: str
    chat_id: str
    patient_id: str
    patient_name: str | None = None
    patient_code: int
    status: str


@router.post("/consultations/fetch-by-code", response_model=FetchByCodeOut)
async def fetch_by_code(
    body: FetchByCodeIn,
    user: Annotated[User, Depends(require_role("doctor"))],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> FetchByCodeOut:
    pf_r = await db.execute(
        select(PatientProfile).where(PatientProfile.patient_code == body.patient_code)
    )
    pf = pf_r.scalar_one_or_none()
    if not pf:
        raise HTTPException(
            status.HTTP_404_NOT_FOUND,
            detail=f"No patient found with code {body.patient_code}.",
        )

    # Already in consultation with THIS doctor → resume.
    c_r = await db.execute(
        select(Consultation).where(
            Consultation.patient_id == pf.user_id,
            Consultation.doctor_id == user.id,
            Consultation.status == "in_consultation",
        )
    )
    ongoing = c_r.scalar_one_or_none()
    if ongoing:
        return FetchByCodeOut(
            consultation_id=str(ongoing.id),
            chat_id=str(ongoing.chat_id),
            patient_id=str(pf.user_id),
            patient_name=pf.full_name,
            patient_code=pf.patient_code,
            status=ongoing.status,
        )

    # Pick up intake_done consult that has no doctor yet.
    c_r = await db.execute(
        select(Consultation).where(
            Consultation.patient_id == pf.user_id,
            Consultation.status == "intake_done",
            Consultation.doctor_id.is_(None),
        )
    )
    consult = c_r.scalar_one_or_none()
    if not consult:
        any_r = await db.execute(
            select(Consultation).where(
                Consultation.patient_id == pf.user_id,
                Consultation.status != "closed",
            )
        )
        any_active = any_r.scalar_one_or_none()
        if any_active is None:
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                detail="Patient has no active consultation. Ask them to start one.",
            )
        if any_active.status == "intake_pending":
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                detail="Patient has not finished their intake chat yet.",
            )
        if any_active.status == "in_consultation" and any_active.doctor_id != user.id:
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                detail="Patient is already in consultation with another doctor.",
            )
        raise HTTPException(status.HTTP_409_CONFLICT, detail="Consultation not available.")

    chat_r = await db.execute(
        select(Chat).where(Chat.patient_id == pf.user_id, Chat.doctor_id == user.id)
    )
    chat = chat_r.scalar_one_or_none()
    if not chat:
        chat = Chat(patient_id=pf.user_id, doctor_id=user.id)
        db.add(chat)
        await db.flush()

    consult.chat_id = chat.id
    consult.doctor_id = user.id
    consult.status = "in_consultation"
    consult.started_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(consult)

    return FetchByCodeOut(
        consultation_id=str(consult.id),
        chat_id=str(chat.id),
        patient_id=str(pf.user_id),
        patient_name=pf.full_name,
        patient_code=pf.patient_code,
        status=consult.status,
    )


@router.get("/consultations/{cid}", response_model=dict)
async def get_consultation_detail(
    cid: str,
    user: Annotated[User, Depends(require_role("doctor"))],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict:
    r = await db.execute(
        select(Consultation).where(
            Consultation.id == cid, Consultation.doctor_id == user.id
        )
    )
    c = r.scalar_one_or_none()
    if not c:
        raise HTTPException(status.HTTP_404_NOT_FOUND)

    pf_r = await db.execute(
        select(PatientProfile).where(PatientProfile.user_id == c.patient_id)
    )
    pf = pf_r.scalar_one_or_none()

    return {
        "id": str(c.id),
        "status": c.status,
        "patient_id": str(c.patient_id),
        "patient_name": pf.full_name if pf else None,
        "patient_code": pf.patient_code if pf else None,
        "patient_dob": pf.dob.isoformat() if pf and pf.dob else None,
        "patient_sex": pf.sex if pf else None,
        "patient_phone": pf.phone if pf else None,
        "patient_allergies": pf.allergies if pf else None,
        "patient_conditions": pf.conditions if pf else None,
        "patient_current_meds": pf.current_meds if pf else None,
        "intake_summary": c.intake_summary_json,
        "analysis": c.analysis_json,
        "started_at": c.started_at.isoformat() if c.started_at else None,
        "closed_at": c.closed_at.isoformat() if c.closed_at else None,
    }


@router.get("/consultations/{cid}/messages", response_model=list[dict])
async def list_doctor_messages(
    cid: str,
    user: Annotated[User, Depends(require_role("doctor"))],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> list[dict]:
    r = await db.execute(
        select(Consultation).where(
            Consultation.id == cid, Consultation.doctor_id == user.id
        )
    )
    if not r.scalar_one_or_none():
        raise HTTPException(status.HTTP_404_NOT_FOUND)
    msg_r = await db.execute(
        select(ChatMessage)
        .where(ChatMessage.consultation_id == cid)
        .order_by(ChatMessage.created_at.asc())
    )
    return [
        {
            "id": str(m.id),
            "sender_role": m.sender_role,
            "content_type": m.content_type,
            "content": m.content,
            "payload": m.payload,
            "visibility": m.visibility,
            "created_at": m.created_at.isoformat(),
        }
        for m in msg_r.scalars().all()
    ]


@router.post("/consultations/{cid}/close", response_model=dict)
async def close_consultation(
    cid: str,
    user: Annotated[User, Depends(require_role("doctor"))],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict:
    r = await db.execute(
        select(Consultation).where(
            Consultation.id == cid, Consultation.doctor_id == user.id
        )
    )
    c = r.scalar_one_or_none()
    if not c:
        raise HTTPException(status.HTTP_404_NOT_FOUND)
    if c.status == "closed":
        return {"ok": True, "status": "closed"}
    c.status = "closed"
    c.closed_at = datetime.now(timezone.utc)
    await db.commit()
    return {"ok": True, "status": "closed"}
