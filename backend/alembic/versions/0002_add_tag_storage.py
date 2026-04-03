"""add canonical tag storage

Revision ID: 0002_add_tag_storage
Revises: 0001_initial_schema
Create Date: 2026-03-31 00:00:00
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "0002_add_tag_storage"
down_revision = "0001_initial_schema"
branch_labels = None
depends_on = None


def _column_names(inspector: sa.Inspector, table_name: str) -> set[str]:
    try:
        return {item["name"] for item in inspector.get_columns(table_name)}
    except Exception:
        return set()


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())
    if "dishes" not in tables:
        return

    columns = _column_names(inspector, "dishes")

    if "tags_json" not in columns:
        op.add_column(
            "dishes",
            sa.Column("tags_json", sa.JSON(), nullable=False, server_default=sa.text("'{}'")),
        )
    if "raw_tagging_output" not in columns:
        op.add_column("dishes", sa.Column("raw_tagging_output", sa.JSON(), nullable=True))
    if "candidate_tags_json" not in columns:
        op.add_column("dishes", sa.Column("candidate_tags_json", sa.JSON(), nullable=True))
    if "tagging_trace_json" not in columns:
        op.add_column("dishes", sa.Column("tagging_trace_json", sa.JSON(), nullable=True))
    if "tagging_version" not in columns:
        op.add_column(
            "dishes",
            sa.Column("tagging_version", sa.String(length=30), nullable=False, server_default="v1"),
        )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())
    if "dishes" not in tables:
        return

    columns = _column_names(inspector, "dishes")
    if "tagging_version" in columns:
        op.drop_column("dishes", "tagging_version")
    if "tagging_trace_json" in columns:
        op.drop_column("dishes", "tagging_trace_json")
    if "candidate_tags_json" in columns:
        op.drop_column("dishes", "candidate_tags_json")
    if "raw_tagging_output" in columns:
        op.drop_column("dishes", "raw_tagging_output")
    if "tags_json" in columns:
        op.drop_column("dishes", "tags_json")
