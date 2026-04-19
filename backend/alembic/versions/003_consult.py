"""consultation tables: chats, consultations, chat_messages, audio_recordings, prescriptions, prescription_pdfs

Revision ID: 003_consult
Revises: 002_auth
Create Date: 2026-04-19
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB, UUID


revision: str = "003_consult"
down_revision: Union[str, None] = "002_auth"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "chats",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "patient_id",
            UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "doctor_id",
            UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("patient_id", "doctor_id", name="uq_chat_patient_doctor"),
    )
    op.create_index("ix_chats_patient_id", "chats", ["patient_id"])
    op.create_index("ix_chats_doctor_id", "chats", ["doctor_id"])

    op.create_table(
        "consultations",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "patient_id",
            UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "chat_id",
            UUID(as_uuid=True),
            sa.ForeignKey("chats.id", ondelete="SET NULL"),
        ),
        sa.Column(
            "doctor_id",
            UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
        ),
        sa.Column("status", sa.String(32), nullable=False, server_default="intake_pending"),
        sa.Column("intake_summary_json", JSONB),
        sa.Column("analysis_json", JSONB),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("intake_done_at", sa.DateTime(timezone=True)),
        sa.Column("started_at", sa.DateTime(timezone=True)),
        sa.Column("closed_at", sa.DateTime(timezone=True)),
        sa.CheckConstraint(
            "status IN ('intake_pending','intake_done','in_consultation','closed')",
            name="consultations_status_check",
        ),
    )
    op.create_index("ix_consultations_patient_id", "consultations", ["patient_id"])
    op.create_index("ix_consultations_chat_id", "consultations", ["chat_id"])
    op.create_index("ix_consultations_doctor_id", "consultations", ["doctor_id"])

    op.create_table(
        "chat_messages",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "consultation_id",
            UUID(as_uuid=True),
            sa.ForeignKey("consultations.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("sender_role", sa.String(20), nullable=False),
        sa.Column("content_type", sa.String(30), nullable=False, server_default="text"),
        sa.Column("content", sa.Text()),
        sa.Column("payload", JSONB),
        sa.Column("visibility", sa.String(16), nullable=False, server_default="both"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "visibility IN ('both','doctor_only')",
            name="chat_messages_visibility_check",
        ),
    )
    op.create_index(
        "ix_chat_messages_consultation_id", "chat_messages", ["consultation_id"]
    )
    op.create_index("ix_chat_messages_created_at", "chat_messages", ["created_at"])

    op.create_table(
        "audio_recordings",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "consultation_id",
            UUID(as_uuid=True),
            sa.ForeignKey("consultations.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("audio_bytes", sa.LargeBinary(), nullable=False),
        sa.Column("mime_type", sa.String(64)),
        sa.Column("duration_s", sa.Integer()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(
        "ix_audio_recordings_consultation_id", "audio_recordings", ["consultation_id"]
    )

    op.create_table(
        "prescriptions",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "consultation_id",
            UUID(as_uuid=True),
            sa.ForeignKey("consultations.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("items_json", JSONB),
        sa.Column("advice", sa.Text()),
        sa.Column("follow_up", sa.Text()),
        sa.Column("signed_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(
        "ix_prescriptions_consultation_id", "prescriptions", ["consultation_id"]
    )

    op.create_table(
        "prescription_pdfs",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "prescription_id",
            UUID(as_uuid=True),
            sa.ForeignKey("prescriptions.id", ondelete="CASCADE"),
            nullable=False,
            unique=True,
        ),
        sa.Column("pdf_bytes", sa.LargeBinary(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("prescription_pdfs")
    op.drop_index("ix_prescriptions_consultation_id", table_name="prescriptions")
    op.drop_table("prescriptions")
    op.drop_index("ix_audio_recordings_consultation_id", table_name="audio_recordings")
    op.drop_table("audio_recordings")
    op.drop_index("ix_chat_messages_created_at", table_name="chat_messages")
    op.drop_index("ix_chat_messages_consultation_id", table_name="chat_messages")
    op.drop_table("chat_messages")
    op.drop_index("ix_consultations_doctor_id", table_name="consultations")
    op.drop_index("ix_consultations_chat_id", table_name="consultations")
    op.drop_index("ix_consultations_patient_id", table_name="consultations")
    op.drop_table("consultations")
    op.drop_index("ix_chats_doctor_id", table_name="chats")
    op.drop_index("ix_chats_patient_id", table_name="chats")
    op.drop_table("chats")
