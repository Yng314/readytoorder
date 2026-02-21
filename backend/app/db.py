import os

from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import DeclarativeBase, sessionmaker


def _normalize_database_url(raw: str) -> str:
    if raw.startswith("postgres://"):
        return raw.replace("postgres://", "postgresql+psycopg://", 1)
    if raw.startswith("postgresql://") and "+psycopg" not in raw:
        return raw.replace("postgresql://", "postgresql+psycopg://", 1)
    return raw


DATABASE_URL = _normalize_database_url(
    os.getenv("DATABASE_URL", "sqlite:///./readytoorder.db")
)

engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
    future=True,
)

SessionLocal = sessionmaker(
    bind=engine,
    autocommit=False,
    autoflush=False,
    expire_on_commit=False,
)


class Base(DeclarativeBase):
    pass


def init_db() -> None:
    from . import models  # noqa: F401

    Base.metadata.create_all(bind=engine)
    _ensure_schema_compatibility()


def _ensure_schema_compatibility() -> None:
    inspector = inspect(engine)
    try:
        dish_columns = {column["name"] for column in inspector.get_columns("dishes")}
    except Exception:
        return

    if "category_tags" not in dish_columns:
        with engine.begin() as conn:
            conn.execute(text("ALTER TABLE dishes ADD COLUMN category_tags JSON"))
