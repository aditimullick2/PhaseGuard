"""
database.py — Database connection and models setup.

Uses SQLAlchemy with asyncpg (async PostgreSQL driver) for voice profile persistence.
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlalchemy import DateTime, String, Text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

from core.config import get_settings


class Base(DeclarativeBase):
    """Base class for all database models."""
    pass


class VoiceProfileDB(Base):
    """
    Database model for voice profiles.

    Stores voice cloning metadata and provider information.
    Voice audio samples are NOT stored — only metadata and provider references.
    """
    __tablename__ = "voice_profiles"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    provider: Mapped[str] = mapped_column(String(50), nullable=False, index=True)
    provider_voice_id: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    display_name: Mapped[str] = mapped_column(String(200), nullable=False)
    status: Mapped[str] = mapped_column(String(50), default="active", nullable=False)
    user_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)
    profile_metadata: Mapped[Optional[str]] = mapped_column(Text, nullable=True)


# ── Database engine and session ───────────────────────────────────────────────

def get_engine():
    """Create async database engine from settings."""
    settings = get_settings()
    # Parse connection string and add SSL parameters for Neon
    return create_async_engine(
        settings.database_url,
        echo=settings.debug,  # Log SQL queries in debug mode
        pool_pre_ping=True,  # Check connection health before using
        connect_args={
            "server_settings": {
                "sslmode": "require",
            }
        }
    )


def get_session_factory():
    """Create async session factory."""
    engine = get_engine()
    return async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )


# Global engine and session factory (initialized at startup)
_engine = None
_session_factory = None


def init_db():
    """Initialize database engine and session factory."""
    global _engine, _session_factory
    if _engine is None:
        _engine = get_engine()
        _session_factory = get_session_factory()


async def get_db_session() -> AsyncSession:
    """
    Dependency to get database session.

    Usage in FastAPI:
        @router.get("/voices")
        async def list_voices(db: AsyncSession = Depends(get_db_session)):
            ...
    """
    if _session_factory is None:
        init_db()
    async with _session_factory() as session:
        yield session


async def create_tables():
    """Create all tables (useful for development, not production)."""
    engine = get_engine()
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


async def drop_tables():
    """Drop all tables (useful for development/testing)."""
    engine = get_engine()
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
