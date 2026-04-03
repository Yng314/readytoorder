"""add user auth and profile tables

Revision ID: 0003_add_user_auth_and_profiles
Revises: 0002_add_tag_storage
Create Date: 2026-03-31 00:00:00
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "0003_add_user_auth_and_profiles"
down_revision = "0002_add_tag_storage"
branch_labels = None
depends_on = None


def _table_names(inspector: sa.Inspector) -> set[str]:
    try:
        return set(inspector.get_table_names())
    except Exception:
        return set()


def _index_names(inspector: sa.Inspector, table_name: str) -> set[str]:
    try:
        return {item["name"] for item in inspector.get_indexes(table_name)}
    except Exception:
        return set()


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = _table_names(inspector)

    if "users" not in tables:
        op.create_table(
            "users",
            sa.Column("id", sa.String(length=36), nullable=False),
            sa.Column("apple_user_id", sa.String(length=120), nullable=False),
            sa.Column("email", sa.String(length=255), nullable=True),
            sa.Column("display_name", sa.String(length=120), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("last_login_at", sa.DateTime(timezone=True), nullable=False),
            sa.PrimaryKeyConstraint("id"),
        )

    user_indexes = _index_names(inspector, "users")
    if "ix_users_apple_user_id" not in user_indexes:
        op.create_index("ix_users_apple_user_id", "users", ["apple_user_id"], unique=True)
    if "ix_users_last_login_at" not in user_indexes:
        op.create_index("ix_users_last_login_at", "users", ["last_login_at"], unique=False)

    if "user_profiles" not in tables:
        op.create_table(
            "user_profiles",
            sa.Column("user_id", sa.String(length=36), nullable=False),
            sa.Column("taste_profile_json", sa.JSON(), nullable=False, server_default=sa.text("'{}'")),
            sa.Column("analysis_json", sa.JSON(), nullable=True),
            sa.Column("preferences_json", sa.JSON(), nullable=False, server_default=sa.text("'{}'")),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
            sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
            sa.PrimaryKeyConstraint("user_id"),
        )

    if "user_swipe_events" not in tables:
        op.create_table(
            "user_swipe_events",
            sa.Column("id", sa.String(length=36), nullable=False),
            sa.Column("user_id", sa.String(length=36), nullable=False),
            sa.Column("dish_name", sa.String(length=120), nullable=False, server_default=""),
            sa.Column("action", sa.String(length=20), nullable=False, server_default="neutral"),
            sa.Column("dish_snapshot_json", sa.JSON(), nullable=False, server_default=sa.text("'{}'")),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
            sa.PrimaryKeyConstraint("id"),
        )

    swipe_indexes = _index_names(inspector, "user_swipe_events")
    if "ix_user_swipe_events_user_id" not in swipe_indexes:
        op.create_index("ix_user_swipe_events_user_id", "user_swipe_events", ["user_id"], unique=False)
    if "ix_user_swipe_events_user_created_at" not in swipe_indexes:
        op.create_index(
            "ix_user_swipe_events_user_created_at",
            "user_swipe_events",
            ["user_id", "created_at"],
            unique=False,
        )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = _table_names(inspector)

    if "user_swipe_events" in tables:
        indexes = _index_names(inspector, "user_swipe_events")
        if "ix_user_swipe_events_user_created_at" in indexes:
            op.drop_index("ix_user_swipe_events_user_created_at", table_name="user_swipe_events")
        if "ix_user_swipe_events_user_id" in indexes:
            op.drop_index("ix_user_swipe_events_user_id", table_name="user_swipe_events")
        op.drop_table("user_swipe_events")

    if "user_profiles" in tables:
        op.drop_table("user_profiles")

    if "users" in tables:
        indexes = _index_names(inspector, "users")
        if "ix_users_last_login_at" in indexes:
            op.drop_index("ix_users_last_login_at", table_name="users")
        if "ix_users_apple_user_id" in indexes:
            op.drop_index("ix_users_apple_user_id", table_name="users")
        op.drop_table("users")
