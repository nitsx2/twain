import logging
from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import require_role
from app.claude_client import get_claude
from app.db import get_db
from app.models import ChatMessage, Consultation, User
from app.prompts import INTAKE_SUMMARY_SYSTEM, INTAKE_SYSTEM

log = logging.getLogger("twain.patient")

router = APIRouter(prefix="/api/patient", tags=["patient"])


class ConsultationOut(BaseModel):
    id: str
    status: str
    created_at: str
    intake_done_at: str | None = None
    started_at: str | None = None
    closed_at: str | None = None
    intake_summary: dict | None = None


class ActiveConsultationOut(BaseModel):
    active: bool
    consultation: ConsultationOut | None = None


class MessageOut(BaseModel):
    id: str
    sender_role: str
    content_type: str
    content: str | None = None
    payload: dict | None = None
    visibility: str
    created_at: str


class MessageSendIn(BaseModel):
    content: str


def _serialize_consult(c: Consultation) -> ConsultationOut:
    return ConsultationOut(
        id=str(c.id),
        status=c.status,
        created_at=c.created_at.isoformat(),
        intake_done_at=c.intake_done_at.isoformat() if c.intake_done_at else None,
        started_at=c.started_at.isoformat() if c.started_at else None,
        closed_at=c.closed_at.isoformat() if c.closed_at else None,
        intake_summary=c.intake_summary_json,
    )


def _serialize_msg(m: ChatMessage) -> MessageOut:
    return MessageOut(
        id=str(m.id),
        sender_role=m.sender_role,
        content_type=m.content_type,
        content=m.content,
        payload=m.payload,
        visibility=m.visibility,
        created_at=m.created_at.isoformat(),
    )


async def _require_patient_consult(
    db: AsyncSession, cid: str, user_id
) -> Consultation:
    r = await db.execute(
        select(Consultation).where(
            Consultation.id == cid, Consultation.patient_id == user_id
        )
    )
    c = r.scalar_one_or_none()
    if not c:
        raise HTTPException(status.HTTP_404_NOT_FOUND)
    return c


async def _load_messages(db: AsyncSession, cid: str) -> list[ChatMessage]:
    r = await db.execute(
        select(ChatMessage)
        .where(ChatMessage.consultation_id == cid)
        .order_by(ChatMessage.created_at.asc())
    )
    return list(r.scalars().all())


@router.get("/active-consultation", response_model=ActiveConsultationOut)
async def active_consultation(
    user: Annotated[User, Depends(require_role("patient"))],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ActiveConsultationOut:
    r = await db.execute(
        select(Consultation)
        .where(Consultation.patient_id == user.id, Consultation.status != "closed")
        .order_by(Consultation.created_at.desc())
        .limit(1)
    )
    c = r.scalar_one_or_none()
    if not c:
        return ActiveConsultationOut(active=False)
    return ActiveConsultationOut(active=True, consultation=_serialize_consult(c))


@router.get("/consultations", response_model=list[dict])
async def list_patient_consultations(
    user: Annotated[User, Depends(require_role("patient"))],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> list[dict]:
    r = await db.execute(
        select(Consultation)
        .where(Consultation.patient_id == user.id)
        .order_by(Consultation.created_at.desc())
    )
    out: list[dict] = []
    for c in r.scalars().all():
        analysis = c.analysis_json or {}
        out.append(
            {
                "id": str(c.id),
                "status": c.status,
                "created_at": c.created_at.isoformat(),
                "intake_done_at": c.intake_done_at.isoformat() if c.intake_done_at else None,
                "started_at": c.started_at.isoformat() if c.started_at else None,
                "closed_at": c.closed_at.isoformat() if c.closed_at else None,
                "diagnosis": analysis.get("patient_diagnosis") if isinstance(analysis, dict) else None,
            }
        )
    return out


@router.post("/consultations", response_model=ConsultationOut)
async def create_consultation(
    user: Annotated[User, Depends(require_role("patient"))],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ConsultationOut:
    r = await db.execute(
        select(Consultation).where(
            Consultation.patient_id == user.id, Consultation.status != "closed"
        )
    )
    if r.scalar_one_or_none():
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            detail="You already have an active consultation.",
        )
    c = Consultation(patient_id=user.id, status="intake_pending")
    db.add(c)
    await db.commit()
    await db.refresh(c)

    # Seed opening question from Twain AI.
    try:
        opening = await get_claude().chat(
            messages=[{"role": "user", "content": "Begin."}],
            system=INTAKE_SYSTEM,
            max_tokens=300,
        )
        db.add(
            ChatMessage(
                consultation_id=c.id,
                sender_role="twain_ai",
                content_type="intake_q",
                content=opening,
                visibility="both",
            )
        )
        await db.commit()
    except Exception as e:
        log.exception("Intake opener failed: %s", e)
        await db.rollback()

    await db.refresh(c)
    return _serialize_consult(c)


@router.post("/consultations/{cid}/cancel", response_model=ConsultationOut)
async def cancel_consultation(
    cid: str,
    user: Annotated[User, Depends(require_role("patient"))],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ConsultationOut:
    c = await _require_patient_consult(db, cid, user.id)
    if c.status not in ("intake_pending", "intake_done"):
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            detail="Cannot cancel once the doctor has started.",
        )
    c.status = "closed"
    c.closed_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(c)
    return _serialize_consult(c)


@router.get("/consultations/{cid}/messages", response_model=list[MessageOut])
async def list_messages(
    cid: str,
    user: Annotated[User, Depends(require_role("patient"))],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> list[MessageOut]:
    await _require_patient_consult(db, cid, user.id)
    r = await db.execute(
        select(ChatMessage)
        .where(
            ChatMessage.consultation_id == cid,
            ChatMessage.visibility == "both",
        )
        .order_by(ChatMessage.created_at.asc())
    )
    return [_serialize_msg(m) for m in r.scalars().all()]


@router.post("/consultations/{cid}/messages", response_model=list[MessageOut])
async def send_message(
    cid: str,
    body: MessageSendIn,
    user: Annotated[User, Depends(require_role("patient"))],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> list[MessageOut]:
    c = await _require_patient_consult(db, cid, user.id)
    if c.status != "intake_pending":
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST, detail="Intake is already complete."
        )
    if not body.content.strip():
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Empty message")

    user_msg = ChatMessage(
        consultation_id=c.id,
        sender_role="patient",
        content_type="intake_a",
        content=body.content.strip(),
        visibility="both",
    )
    db.add(user_msg)
    await db.flush()

    history = await _load_messages(db, cid)
    claude_msgs: list[dict[str, str]] = []
    for m in history:
        if m.content is None:
            continue
        role = "assistant" if m.sender_role == "twain_ai" else "user"
        claude_msgs.append({"role": role, "content": m.content})

    try:
        reply = await get_claude().chat(
            messages=claude_msgs,
            system=INTAKE_SYSTEM,
            max_tokens=400,
        )
    except Exception as e:
        log.exception("Claude intake failed: %s", e)
        await db.rollback()
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY,
            detail="AI is temporarily unavailable. Try again.",
        ) from e

    ai_msg = ChatMessage(
        consultation_id=c.id,
        sender_role="twain_ai",
        content_type="intake_q",
        content=reply,
        visibility="both",
    )
    db.add(ai_msg)
    await db.commit()

    return [_serialize_msg(user_msg), _serialize_msg(ai_msg)]


@router.get("/consultations", response_model=list[ConsultationOut])
async def list_consultations(
    user: Annotated[User, Depends(require_role("patient"))],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> list[ConsultationOut]:
    r = await db.execute(
        select(Consultation)
        .where(Consultation.patient_id == user.id)
        .order_by(Consultation.created_at.desc())
    )
    return [_serialize_consult(c) for c in r.scalars().all()]


@router.post(
    "/consultations/{cid}/finalize-intake", response_model=ConsultationOut
)
async def finalize_intake(
    cid: str,
    user: Annotated[User, Depends(require_role("patient"))],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ConsultationOut:
    c = await _require_patient_consult(db, cid, user.id)
    if c.status != "intake_pending":
        return _serialize_consult(c)

    history = await _load_messages(db, cid)
    if len([m for m in history if m.sender_role == "patient"]) < 1:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            detail="Answer at least one question before finishing.",
        )

    lines: list[str] = []
    for m in history:
        if not m.content:
            continue
        who = "Patient" if m.sender_role == "patient" else "Twain AI"
        lines.append(f"{who}: {m.content}")
    transcript = "\n".join(lines)

    try:
        summary = await get_claude().chat_json(
            messages=[
                {
                    "role": "user",
                    "content": f"Intake transcript:\n\"\"\"\n{transcript}\n\"\"\"\nReturn the JSON summary now.",
                }
            ],
            system=INTAKE_SUMMARY_SYSTEM,
            max_tokens=1200,
        )
    except Exception as e:
        log.exception("Intake summary failed: %s", e)
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY,
            detail="Could not summarise intake — try again.",
        ) from e

    c.intake_summary_json = summary
    c.status = "intake_done"
    c.intake_done_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(c)
    return _serialize_consult(c)
