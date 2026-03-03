import os
from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker


def _normalize_database_url(raw: str) -> str:
    if raw.startswith("postgres://"):
        return raw.replace("postgres://", "postgresql+psycopg://", 1)
    if raw.startswith("postgresql://") and "+psycopg" not in raw:
        return raw.replace("postgresql://", "postgresql+psycopg://", 1)
    return raw


APP_ENV = os.getenv("APP_ENV", "development").strip().lower()
RAW_DATABASE_URL = os.getenv("DATABASE_URL", "").strip()

if APP_ENV == "production" and not RAW_DATABASE_URL:
    raise RuntimeError("DATABASE_URL is required when APP_ENV=production")

if not RAW_DATABASE_URL:
    RAW_DATABASE_URL = "sqlite:///./readytoorder.db"

DATABASE_URL = _normalize_database_url(RAW_DATABASE_URL)

if APP_ENV == "production" and not DATABASE_URL.startswith("postgresql+psycopg://"):
    raise RuntimeError("Production environment requires a PostgreSQL DATABASE_URL")

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
    _run_migrations()


def _run_migrations() -> None:
    backend_root = Path(__file__).resolve().parents[1]
    alembic_ini = backend_root / "alembic.ini"
    alembic_script_dir = backend_root / "alembic"

    if not alembic_ini.exists():
        raise RuntimeError(f"Alembic config not found: {alembic_ini}")
    if not alembic_script_dir.exists():
        raise RuntimeError(f"Alembic script directory not found: {alembic_script_dir}")

    config = Config(str(alembic_ini))
    config.set_main_option("sqlalchemy.url", DATABASE_URL)
    config.set_main_option("script_location", str(alembic_script_dir))
    command.upgrade(config, "head")
