"""initial baseline

Revision ID: 001_initial
Revises:
Create Date: 2026-04-19 00:00:00

Empty baseline. Subsequent revisions (002_auth, 003_consult, ...) add tables as phases progress.
"""
from typing import Sequence, Union

from alembic import op  # noqa: F401
import sqlalchemy as sa  # noqa: F401


revision: str = "001_initial"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
