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


Index("ix_dishes_status_created_at", Dish.status, Dish.created_at)
Index("ix_generation_jobs_kind_created_at", GenerationJob.kind, GenerationJob.created_at)
