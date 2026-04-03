import uuid
from datetime import datetime, timezone

from sqlalchemy import DateTime, ForeignKey, Index, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class DishImage(Base):
    __tablename__ = "dish_images"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    provider: Mapped[str] = mapped_column(String(40), nullable=False, default="gemini")
    model: Mapped[str] = mapped_column(String(80), nullable=False, default="")
    prompt: Mapped[str] = mapped_column(Text, nullable=False, default="")
    mime_type: Mapped[str] = mapped_column(String(50), nullable=False, default="image/png")
    data_url: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utc_now)


class Dish(Base):
    __tablename__ = "dishes"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    name: Mapped[str] = mapped_column(String(80), nullable=False, unique=True, index=True)
    subtitle: Mapped[str] = mapped_column(String(160), nullable=False)
    signals: Mapped[dict] = mapped_column(JSON, nullable=False)
    category_tags: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    tags_json: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
    raw_tagging_output: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    candidate_tags_json: Mapped[list | None] = mapped_column(JSON, nullable=True)
    tagging_trace_json: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    tagging_version: Mapped[str] = mapped_column(String(30), nullable=False, default="v1")
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="ready")
    source: Mapped[str] = mapped_column(String(30), nullable=False, default="gemini")
    image_id: Mapped[str | None] = mapped_column(String(36), ForeignKey("dish_images.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utc_now)


class GenerationJob(Base):
    __tablename__ = "generation_jobs"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    kind: Mapped[str] = mapped_column(String(30), nullable=False, default="deck_refill")
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="running")
    target_count: Mapped[int] = mapped_column(nullable=False, default=0)
    produced_count: Mapped[int] = mapped_column(nullable=False, default=0)
    error: Mapped[str] = mapped_column(Text, nullable=False, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utc_now)
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utc_now)
    finished_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class ClientErrorEvent(Base):
    __tablename__ = "client_error_events"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    device_id: Mapped[str] = mapped_column(String(36), nullable=False, index=True)
    client_version: Mapped[str] = mapped_column(String(40), nullable=False, default="")
    scope: Mapped[str] = mapped_column(String(60), nullable=False, default="unknown")
    code: Mapped[str] = mapped_column(String(60), nullable=False, default="unknown")
    message: Mapped[str] = mapped_column(Text, nullable=False, default="")
    status_code: Mapped[int | None] = mapped_column(nullable=True)
    request_id: Mapped[str] = mapped_column(String(80), nullable=False, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utc_now)


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )
    apple_user_id: Mapped[str] = mapped_column(String(120), nullable=False, unique=True, index=True)
    email: Mapped[str | None] = mapped_column(String(255), nullable=True)
    display_name: Mapped[str | None] = mapped_column(String(120), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utc_now)
    last_login_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utc_now)


class UserProfile(Base):
    __tablename__ = "user_profiles"

    user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("users.id"),
        primary_key=True,
    )
    taste_profile_json: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
    analysis_json: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    preferences_json: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utc_now)


class UserSwipeEvent(Base):
    __tablename__ = "user_swipe_events"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
    )
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    dish_name: Mapped[str] = mapped_column(String(120), nullable=False, default="")
    action: Mapped[str] = mapped_column(String(20), nullable=False, default="neutral")
    dish_snapshot_json: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utc_now)


Index("ix_dishes_status_created_at", Dish.status, Dish.created_at)
Index("ix_generation_jobs_kind_created_at", GenerationJob.kind, GenerationJob.created_at)
Index("ix_client_error_events_created_at", ClientErrorEvent.created_at)
Index("ix_users_last_login_at", User.last_login_at)
Index("ix_user_swipe_events_user_created_at", UserSwipeEvent.user_id, UserSwipeEvent.created_at)
