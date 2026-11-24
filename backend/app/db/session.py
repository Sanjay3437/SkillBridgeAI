"""Async SQLAlchemy engine and session dependency."""

from collections.abc import AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.core.config import settings

_engine_kwargs: dict = {"pool_pre_ping": True}
if settings.app_env == "test":
    # Tests run in short-lived event loops; pooling across loops is unsafe.
    _engine_kwargs["poolclass"] = NullPool
else:
    _engine_kwargs.update(pool_size=5, max_overflow=10)

engine = create_async_engine(settings.database_url, **_engine_kwargs)

SessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with SessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
