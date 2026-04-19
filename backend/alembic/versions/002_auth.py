"""auth tables: users, patient_profiles, doctor_profiles

Revision ID: 002_auth
Revises: 001_initial
Create Date: 2026-04-19
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID


revision: str = "002_auth"
down_revision: Union[str, None] = "001_initial"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("email", sa.String(320), nullable=False),
        sa.Column("password_hash", sa.Text(), nullable=False),
        sa.Column("role", sa.String(16), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "role IN ('patient','doctor')", name="users_role_check"
        ),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)

    op.create_table(
        "patient_profiles",
        sa.Column(
            "user_id",
            UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("patient_code", sa.Integer(), nullable=False),
        sa.Column("full_name", sa.String(255)),
        sa.Column("dob", sa.Date()),
        sa.Column("sex", sa.String(16)),
        sa.Column("phone", sa.String(32)),
        sa.Column("allergies", sa.Text()),
        sa.Column("conditions", sa.Text()),
        sa.Column("current_meds", sa.Text()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(
        "ix_patient_profiles_patient_code",
        "patient_profiles",
        ["patient_code"],
        unique=True,
    )

    op.create_table(
        "doctor_profiles",
        sa.Column(
            "user_id",
            UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("full_name", sa.String(255)),
        sa.Column("specialty", sa.String(100)),
        sa.Column("registration_no", sa.String(100)),
        sa.Column("clinic_name", sa.String(255)),
        sa.Column("clinic_address", sa.Text()),
        sa.Column("phone", sa.String(32)),
        sa.Column("signature_png", sa.LargeBinary()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("doctor_profiles")
    op.drop_index(
        "ix_patient_profiles_patient_code", table_name="patient_profiles"
    )
    op.drop_table("patient_profiles")
    op.drop_index("ix_users_email", table_name="users")
    op.drop_table("users")
