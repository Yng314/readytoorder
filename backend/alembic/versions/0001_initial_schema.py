"""initial schema

Revision ID: 0001_initial_schema
Revises: 
Create Date: 2026-03-03 00:00:00
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "0001_initial_schema"
down_revision = None
branch_labels = None
depends_on = None


def _index_names(inspector: sa.Inspector, table_name: str) -> set[str]:
    try:
        return {item["name"] for item in inspector.get_indexes(table_name)}
    except Exception:
        return set()


def _column_names(inspector: sa.Inspector, table_name: str) -> set[str]:
    try:
        return {item["name"] for item in inspector.get_columns(table_name)}
    except Exception:
        return set()


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    if "dish_images" not in tables:
        op.create_table(
            "dish_images",
            sa.Column("id", sa.String(length=36), nullable=False),
            sa.Column("provider", sa.String(length=40), nullable=False, server_default="gemini"),
            sa.Column("model", sa.String(length=80), nullable=False, server_default=""),
            sa.Column("prompt", sa.Text(), nullable=False, server_default=""),
            sa.Column("mime_type", sa.String(length=50), nullable=False, server_default="image/png"),
            sa.Column("data_url", sa.Text(), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.PrimaryKeyConstraint("id"),
        )

    if "dishes" not in tables:
        op.create_table(
            "dishes",
            sa.Column("id", sa.String(length=36), nullable=False),
            sa.Column("name", sa.String(length=80), nullable=False),
            sa.Column("subtitle", sa.String(length=160), nullable=False),
            sa.Column("signals", sa.JSON(), nullable=False),
            sa.Column("category_tags", sa.JSON(), nullable=True),
            sa.Column("status", sa.String(length=20), nullable=False, server_default="ready"),
            sa.Column("source", sa.String(length=30), nullable=False, server_default="gemini"),
            sa.Column("image_id", sa.String(length=36), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
            sa.ForeignKeyConstraint(["image_id"], ["dish_images.id"]),
            sa.PrimaryKeyConstraint("id"),
        )
    else:
        dish_columns = _column_names(inspector, "dishes")
        if "category_tags" not in dish_columns:
            op.add_column("dishes", sa.Column("category_tags", sa.JSON(), nullable=True))

    dish_indexes = _index_names(inspector, "dishes")
    if "ix_dishes_name" not in dish_indexes:
        op.create_index("ix_dishes_name", "dishes", ["name"], unique=True)
    if "ix_dishes_status_created_at" not in dish_indexes:
        op.create_index("ix_dishes_status_created_at", "dishes", ["status", "created_at"], unique=False)

    if "generation_jobs" not in tables:
        op.create_table(
            "generation_jobs",
            sa.Column("id", sa.String(length=36), nullable=False),
            sa.Column("kind", sa.String(length=30), nullable=False, server_default="deck_refill"),
            sa.Column("status", sa.String(length=20), nullable=False, server_default="running"),
            sa.Column("target_count", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("produced_count", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("error", sa.Text(), nullable=False, server_default=""),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("finished_at", sa.DateTime(timezone=True), nullable=True),
            sa.PrimaryKeyConstraint("id"),
        )

    generation_indexes = _index_names(inspector, "generation_jobs")
    if "ix_generation_jobs_kind_created_at" not in generation_indexes:
        op.create_index("ix_generation_jobs_kind_created_at", "generation_jobs", ["kind", "created_at"], unique=False)

    if "client_error_events" not in tables:
        op.create_table(
            "client_error_events",
            sa.Column("id", sa.String(length=36), nullable=False),
            sa.Column("device_id", sa.String(length=36), nullable=False),
            sa.Column("client_version", sa.String(length=40), nullable=False, server_default=""),
            sa.Column("scope", sa.String(length=60), nullable=False, server_default="unknown"),
            sa.Column("code", sa.String(length=60), nullable=False, server_default="unknown"),
            sa.Column("message", sa.Text(), nullable=False, server_default=""),
            sa.Column("status_code", sa.Integer(), nullable=True),
            sa.Column("request_id", sa.String(length=80), nullable=False, server_default=""),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.PrimaryKeyConstraint("id"),
        )

    client_error_indexes = _index_names(inspector, "client_error_events")
    if "ix_client_error_events_device_id" not in client_error_indexes:
        op.create_index("ix_client_error_events_device_id", "client_error_events", ["device_id"], unique=False)
    if "ix_client_error_events_created_at" not in client_error_indexes:
        op.create_index("ix_client_error_events_created_at", "client_error_events", ["created_at"], unique=False)


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())

    if "client_error_events" in tables:
        indexes = _index_names(inspector, "client_error_events")
        if "ix_client_error_events_created_at" in indexes:
            op.drop_index("ix_client_error_events_created_at", table_name="client_error_events")
        if "ix_client_error_events_device_id" in indexes:
            op.drop_index("ix_client_error_events_device_id", table_name="client_error_events")
        op.drop_table("client_error_events")

    if "generation_jobs" in tables:
        indexes = _index_names(inspector, "generation_jobs")
        if "ix_generation_jobs_kind_created_at" in indexes:
            op.drop_index("ix_generation_jobs_kind_created_at", table_name="generation_jobs")
        op.drop_table("generation_jobs")

    if "dishes" in tables:
        indexes = _index_names(inspector, "dishes")
        if "ix_dishes_status_created_at" in indexes:
            op.drop_index("ix_dishes_status_created_at", table_name="dishes")
        if "ix_dishes_name" in indexes:
            op.drop_index("ix_dishes_name", table_name="dishes")
        op.drop_table("dishes")

    if "dish_images" in tables:
        op.drop_table("dish_images")
