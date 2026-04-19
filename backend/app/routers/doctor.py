import asyncio
import logging
from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import require_role
from app.claude_client import get_claude
from app.db import get_db
from app.models import (
    AudioRecording,
    Chat,
    ChatMessage,
    Consultation,
    DoctorProfile,
    PatientProfile,
    Prescription,
    PrescriptionPdf,
    User,
)
from app.pdf import render_prescription_pdf
from app.prompts import CONSULT_ANALYSIS_SYSTEM, RX_DRAFT_SYSTEM
from app.qubrid_client import get_qubrid

log = logging.getLogger("twain.doctor")

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


@router.get("/consultations", response_model=list[dict])
async def list_doctor_consultations(
    user: Annotated[User, Depends(require_role("doctor"))],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> list[dict]:
    from sqlalchemy import nullslast
    r = await db.execute(
        select(Consultation, PatientProfile)
        .outerjoin(PatientProfile, PatientProfile.user_id == Consultation.patient_id)
        .where(Consultation.doctor_id == user.id)
        .order_by(nullslast(Consultation.closed_at.desc()), Consultation.created_at.desc())
    )
    result = []
    for c, pf in r.all():
        result.append({
            "id": str(c.id),
            "status": c.status,
            "patient_name": pf.full_name if pf else None,
            "patient_code": pf.patient_code if pf else None,
            "diagnosis": (c.analysis_json or {}).get("patient_diagnosis"),
            "created_at": c.created_at.isoformat(),
            "started_at": c.started_at.isoformat() if c.started_at else None,
            "closed_at": c.closed_at.isoformat() if c.closed_at else None,
        })
    return result


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


@router.post("/consultations/{cid}/recording", response_model=dict)
async def upload_recording(
    cid: str,
    audio: UploadFile = File(...),
    user: User = Depends(require_role("doctor")),
    db: AsyncSession = Depends(get_db),
) -> dict:
    r = await db.execute(
        select(Consultation).where(
            Consultation.id == cid, Consultation.doctor_id == user.id
        )
    )
    c = r.scalar_one_or_none()
    if not c:
        raise HTTPException(status.HTTP_404_NOT_FOUND)
    if c.status != "in_consultation":
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot record while status is {c.status}.",
        )

    audio_bytes = await audio.read()
    if not audio_bytes:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Empty audio")

    mime = audio.content_type or "audio/webm"
    filename = audio.filename or "consult.webm"

    db.add(
        AudioRecording(
            consultation_id=c.id, audio_bytes=audio_bytes, mime_type=mime
        )
    )
    await db.commit()

    try:
        qres = await get_qubrid().transcribe(
            audio_bytes, filename=filename, mime_type=mime, language="en"
        )
    except Exception as e:
        log.exception("Qubrid transcribe failed")
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY, detail=f"Transcription failed: {e}"
        ) from e

    transcript_text = (
        qres.get("text") or qres.get("transcription") or ""
    ).strip()
    if not transcript_text:
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY,
            detail="Transcription returned empty text.",
        )

    db.add(
        ChatMessage(
            consultation_id=c.id,
            sender_role="system",
            content_type="transcript",
            content=transcript_text,
            visibility="doctor_only",
        )
    )

    intake = c.intake_summary_json or {}
    user_msg = (
        "Intake summary (from patient intake chat, JSON):\n"
        f'"""\n{intake}\n"""\n\n'
        "Consultation transcript (single mic, both speakers mixed):\n"
        f'"""\n{transcript_text}\n"""\n\n'
        "Return the JSON object now."
    )
    try:
        analysis = await get_claude().chat_json(
            messages=[{"role": "user", "content": user_msg}],
            system=CONSULT_ANALYSIS_SYSTEM,
            max_tokens=3000,
        )
    except Exception as e:
        log.exception("Claude analysis failed")
        await db.rollback()
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY, detail=f"Analysis failed: {e}"
        ) from e

    c.analysis_json = analysis

    db.add(
        ChatMessage(
            consultation_id=c.id,
            sender_role="brain_ai",
            content_type="summary_full",
            content=None,
            payload=analysis.get("detailed_summary") or analysis,
            visibility="doctor_only",
        )
    )

    diag = (analysis.get("patient_diagnosis") or "").strip()
    actions = analysis.get("patient_action_items") or []
    if diag or actions:
        db.add(
            ChatMessage(
                consultation_id=c.id,
                sender_role="brain_ai",
                content_type="diagnosis",
                content=diag,
                payload={"action_items": actions},
                visibility="both",
            )
        )

    await db.commit()

    return {"ok": True, "transcript": transcript_text, "analysis": analysis}


class BrainMessageIn(BaseModel):
    content: str


@router.post("/consultations/{cid}/brain/messages", response_model=list[dict])
async def brain_chat(
    cid: str,
    body: BrainMessageIn,
    user: Annotated[User, Depends(require_role("doctor"))],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> list[dict]:
    r = await db.execute(
        select(Consultation).where(
            Consultation.id == cid, Consultation.doctor_id == user.id
        )
    )
    c = r.scalar_one_or_none()
    if not c:
        raise HTTPException(status.HTTP_404_NOT_FOUND)
    if c.status != "in_consultation":
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST, detail="Consultation is not active."
        )
    content = body.content.strip()
    if not content:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Empty message")

    doctor_msg = ChatMessage(
        consultation_id=c.id,
        sender_role="doctor",
        content_type="brain_text",
        content=content,
        visibility="doctor_only",
    )
    db.add(doctor_msg)
    await db.flush()

    intake = c.intake_summary_json or {}
    analysis = c.analysis_json or {}

    tx_r = await db.execute(
        select(ChatMessage)
        .where(
            ChatMessage.consultation_id == cid,
            ChatMessage.content_type == "transcript",
        )
        .order_by(ChatMessage.created_at.asc())
    )
    transcript = "\n".join((m.content or "") for m in tx_r.scalars().all()).strip()

    hist_r = await db.execute(
        select(ChatMessage)
        .where(
            ChatMessage.consultation_id == cid,
            ChatMessage.content_type.in_(["brain_text", "rx_draft"]),
        )
        .order_by(ChatMessage.created_at.asc())
    )
    claude_msgs: list[dict[str, str]] = []
    for m in hist_r.scalars().all():
        if m.content_type == "brain_text" and m.content:
            role = "user" if m.sender_role == "doctor" else "assistant"
            claude_msgs.append({"role": role, "content": m.content})
        elif m.content_type == "rx_draft" and m.payload:
            claude_msgs.append(
                {"role": "assistant", "content": f"(earlier Rx draft) {m.payload}"}
            )

    system_prompt = (
        "You are Brain — a senior Indian physician acting as a peer to the doctor in a "
        "clinical chat. Reply conversationally in plain prose (no JSON, no markdown fences). "
        "Be concise and clinically rigorous. If the doctor asks to change something about a "
        "prescription (e.g. reduce duration, swap medicine), acknowledge and state the change "
        "clearly — the next time they tap 'Create prescription' your suggestion will be used.\n\n"
        f"Intake summary: {intake}\n"
        f"Consultation transcript: {transcript or '(no recording yet)'}\n"
        f"Analysis: {analysis}\n"
    )

    try:
        reply = await get_claude().chat(
            messages=claude_msgs,
            system=system_prompt,
            max_tokens=600,
        )
    except Exception as e:
        log.exception("Brain chat failed")
        await db.rollback()
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY, detail=f"Brain chat failed: {e}"
        ) from e

    brain_msg = ChatMessage(
        consultation_id=c.id,
        sender_role="brain_ai",
        content_type="brain_text",
        content=reply,
        visibility="doctor_only",
    )
    db.add(brain_msg)
    await db.commit()
    await db.refresh(doctor_msg)
    await db.refresh(brain_msg)

    def ser(m: ChatMessage) -> dict:
        return {
            "id": str(m.id),
            "sender_role": m.sender_role,
            "content_type": m.content_type,
            "content": m.content,
            "payload": m.payload,
            "visibility": m.visibility,
            "created_at": m.created_at.isoformat(),
        }

    return [ser(doctor_msg), ser(brain_msg)]


class RxDraftOut(BaseModel):
    draft: dict
    message_id: str


@router.post("/consultations/{cid}/rx/draft", response_model=RxDraftOut)
async def draft_rx(
    cid: str,
    user: Annotated[User, Depends(require_role("doctor"))],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> RxDraftOut:
    r = await db.execute(
        select(Consultation).where(
            Consultation.id == cid, Consultation.doctor_id == user.id
        )
    )
    c = r.scalar_one_or_none()
    if not c:
        raise HTTPException(status.HTTP_404_NOT_FOUND)
    if c.status != "in_consultation":
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            detail="Cannot draft prescription — consultation is not active.",
        )

    intake = c.intake_summary_json or {}
    analysis = c.analysis_json or {}

    msg_r = await db.execute(
        select(ChatMessage)
        .where(
            ChatMessage.consultation_id == cid,
            ChatMessage.content_type == "transcript",
        )
        .order_by(ChatMessage.created_at.asc())
    )
    transcript = "\n".join((m.content or "") for m in msg_r.scalars().all()).strip()

    # Pull ALL doctor↔Brain chat + earlier Rx drafts so the new draft
    # reflects refinements like "reduce to 7 days".
    chat_r = await db.execute(
        select(ChatMessage)
        .where(
            ChatMessage.consultation_id == cid,
            ChatMessage.content_type.in_(["brain_text", "rx_draft"]),
        )
        .order_by(ChatMessage.created_at.asc())
    )
    chat_lines: list[str] = []
    latest_draft: dict | None = None
    for m in chat_r.scalars().all():
        if m.content_type == "brain_text":
            who = "Doctor" if m.sender_role == "doctor" else "Brain"
            if m.content:
                chat_lines.append(f"{who}: {m.content}")
        elif m.content_type == "rx_draft" and m.payload:
            latest_draft = m.payload
            chat_lines.append(f"Brain (previous Rx draft): {m.payload}")
    chat_block = "\n".join(chat_lines).strip()

    user_msg = (
        "Intake summary:\n"
        f'"""\n{intake}\n"""\n\n'
        "Transcript:\n"
        f'"""\n{transcript or "(no recording yet)"}\n"""\n\n'
        "Analysis:\n"
        f'"""\n{analysis}\n"""\n\n'
        + (
            f"Doctor ↔ Brain follow-up chat (APPLY these refinements to the new Rx):\n\"\"\"\n{chat_block}\n\"\"\"\n\n"
            if chat_block
            else ""
        )
        + (
            f"Previous Rx draft (use as the base and incorporate chat refinements):\n\"\"\"\n{latest_draft}\n\"\"\"\n\n"
            if latest_draft
            else ""
        )
        + "Return the UPDATED Rx JSON now."
    )
    try:
        draft = await get_claude().chat_json(
            messages=[{"role": "user", "content": user_msg}],
            system=RX_DRAFT_SYSTEM,
            max_tokens=2000,
        )
    except Exception as e:
        log.exception("Rx draft failed")
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY, detail=f"Rx draft failed: {e}"
        ) from e

    msg = ChatMessage(
        consultation_id=c.id,
        sender_role="brain_ai",
        content_type="rx_draft",
        content=None,
        payload=draft,
        visibility="doctor_only",
    )
    db.add(msg)
    await db.commit()
    await db.refresh(msg)
    return RxDraftOut(draft=draft, message_id=str(msg.id))


class RxSignIn(BaseModel):
    medicines: list[dict] = Field(default_factory=list)
    labs: list[str] = Field(default_factory=list)
    lifestyle: list[str] = Field(default_factory=list)
    advice: str | None = None
    follow_up: str | None = None


class RxSignOut(BaseModel):
    prescription_id: str
    pdf_url: str


@router.post("/consultations/{cid}/rx/sign", response_model=RxSignOut)
async def sign_rx(
    cid: str,
    body: RxSignIn,
    user: Annotated[User, Depends(require_role("doctor"))],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> RxSignOut:
    r = await db.execute(
        select(Consultation).where(
            Consultation.id == cid, Consultation.doctor_id == user.id
        )
    )
    c = r.scalar_one_or_none()
    if not c:
        raise HTTPException(status.HTTP_404_NOT_FOUND)
    if c.status != "in_consultation":
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            detail="Cannot sign — consultation is not active.",
        )
    if not body.medicines:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            detail="Add at least one medicine before signing.",
        )

    dp_r = await db.execute(
        select(DoctorProfile).where(DoctorProfile.user_id == user.id)
    )
    dp = dp_r.scalar_one_or_none()
    if not dp or not dp.signature_png:
        raise HTTPException(
            status.HTTP_428_PRECONDITION_REQUIRED,
            detail="Add a signature in your profile before signing prescriptions.",
        )

    pp_r = await db.execute(
        select(PatientProfile).where(PatientProfile.user_id == c.patient_id)
    )
    pp = pp_r.scalar_one_or_none()

    items_json = {
        "medicines": body.medicines,
        "labs": body.labs,
        "lifestyle": body.lifestyle,
    }

    existing_r = await db.execute(
        select(Prescription).where(Prescription.consultation_id == cid)
    )
    prescription = existing_r.scalar_one_or_none()
    now = datetime.now(timezone.utc)
    if prescription:
        prescription.items_json = items_json
        prescription.advice = body.advice
        prescription.follow_up = body.follow_up
        prescription.signed_at = now
    else:
        prescription = Prescription(
            consultation_id=c.id,
            items_json=items_json,
            advice=body.advice,
            follow_up=body.follow_up,
            signed_at=now,
        )
        db.add(prescription)
    await db.flush()

    diag = None
    if c.analysis_json and isinstance(c.analysis_json, dict):
        diag = c.analysis_json.get("patient_diagnosis")

    patient_age: int | None = None
    if pp and pp.dob:
        today = now.date()
        patient_age = (today - pp.dob).days // 365

    try:
        pdf_bytes = await asyncio.to_thread(
            render_prescription_pdf,
            serial_number=str(prescription.id)[:8].upper(),
            doctor_full_name=dp.full_name or user.email,
            specialty=dp.specialty,
            registration_no=dp.registration_no,
            clinic_name=dp.clinic_name,
            clinic_address=dp.clinic_address,
            clinic_phone=dp.phone,
            signature_png=dp.signature_png,
            patient_name=pp.full_name if pp else None,
            patient_age=patient_age,
            patient_sex=pp.sex if pp else None,
            patient_code=pp.patient_code if pp else None,
            diagnosis=diag,
            medicines=body.medicines,
            labs=body.labs,
            lifestyle=body.lifestyle,
            advice=body.advice,
            follow_up=body.follow_up,
        )
    except Exception as e:
        log.exception("PDF render failed")
        await db.rollback()
        raise HTTPException(
            status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"PDF render failed: {e}",
        ) from e

    existing_pdf = await db.execute(
        select(PrescriptionPdf).where(PrescriptionPdf.prescription_id == prescription.id)
    )
    pdf_row = existing_pdf.scalar_one_or_none()
    if pdf_row:
        pdf_row.pdf_bytes = pdf_bytes
    else:
        db.add(PrescriptionPdf(prescription_id=prescription.id, pdf_bytes=pdf_bytes))

    db.add(
        ChatMessage(
            consultation_id=c.id,
            sender_role="doctor",
            content_type="rx_signed",
            content=diag,
            payload={
                "prescription_id": str(prescription.id),
                "medicines": body.medicines,
                "advice": body.advice,
                "follow_up": body.follow_up,
            },
            visibility="both",
        )
    )

    await db.commit()

    return RxSignOut(
        prescription_id=str(prescription.id),
        pdf_url=f"/api/prescriptions/{prescription.id}/pdf",
    )


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
