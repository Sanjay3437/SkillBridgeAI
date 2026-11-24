"""Test environment setup.

Environment variables are set before any `app.*` import so the settings
singleton points at the dedicated test database and local temp storage.
"""

from __future__ import annotations

import asyncio
import os
import tempfile

os.environ["DATABASE_URL"] = (
    "postgresql+asyncpg://skillbridge:skillbridge_dev_pass@localhost:5432/skillbridge_test"
)
os.environ["DATABASE_URL_SYNC"] = (
    "postgresql+psycopg://skillbridge:skillbridge_dev_pass@localhost:5432/skillbridge_test"
)
os.environ["JWT_SECRET"] = "test-secret-key-0123456789abcdef"
os.environ["LLM_PROVIDER"] = "mock"
os.environ["EMBEDDINGS_ENABLED"] = "false"
os.environ["STORAGE_BACKEND"] = "local"
os.environ["STORAGE_LOCAL_DIR"] = tempfile.mkdtemp(prefix="skillbridge-test-uploads-")
os.environ["APP_ENV"] = "test"

import asyncpg  # noqa: E402
import pytest  # noqa: E402
from httpx import ASGITransport, AsyncClient  # noqa: E402
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine  # noqa: E402
from sqlalchemy.pool import NullPool  # noqa: E402

from app.db.base import Base  # noqa: E402
from app.main import app  # noqa: E402
from app.models import *  # noqa: E402,F401,F403

TEST_DATABASE = "skillbridge_test"
TEST_URL = os.environ["DATABASE_URL"]

_db_initialized = False


async def _ensure_database() -> None:
    conn = await asyncpg.connect(
        "postgresql://skillbridge:skillbridge_dev_pass@localhost:5432/postgres", timeout=3
    )
    try:
        exists = await conn.fetchval("SELECT 1 FROM pg_database WHERE datname = $1", TEST_DATABASE)
        if not exists:
            await conn.execute(f'CREATE DATABASE "{TEST_DATABASE}"')
    finally:
        await conn.close()


async def _init_database() -> None:
    global _db_initialized
    if _db_initialized:
        return
    await _ensure_database()
    engine = create_async_engine(TEST_URL, poolclass=NullPool)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    await engine.dispose()
    _db_initialized = True


@pytest.fixture
async def test_engine():
    try:
        await _init_database()
    except Exception as exc:  # pragma: no cover - environment dependent
        pytest.skip(f"PostgreSQL is not available for integration tests: {exc}")
    engine = create_async_engine(TEST_URL, poolclass=NullPool)
    yield engine
    await engine.dispose()


async def _clean(engine) -> None:
    async with engine.begin() as conn:
        for table in reversed(Base.metadata.sorted_tables):
            await conn.execute(table.delete())


@pytest.fixture
async def db_session(test_engine):
    session_factory = async_sessionmaker(bind=test_engine, expire_on_commit=False)
    async with session_factory() as session:
        yield session
    await _clean(test_engine)


@pytest.fixture
async def client(test_engine):
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as ac:
        yield ac
    await _clean(test_engine)


async def register(
    client: AsyncClient, email: str = "user@example.com", password: str = "password123"
) -> dict:
    response = await client.post(
        "/api/v1/auth/register", json={"email": email, "password": password}
    )
    assert response.status_code == 201, response.text
    return response.json()


def auth_headers(tokens: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['tokens']['access_token']}"}


async def wait_for_status(
    client: AsyncClient,
    url: str,
    headers: dict[str, str],
    expected: set[str] | None = None,
    attempts: int = 40,
) -> dict:
    expected = expected or {"completed", "failed"}
    last = None
    for _ in range(attempts):
        response = await client.get(url, headers=headers)
        assert response.status_code == 200, response.text
        last = response.json()
        if last["status"] in expected:
            return last
        await asyncio.sleep(0.05)
    raise AssertionError(f"Timed out waiting for {url}: {last}")


def make_pdf(text: str) -> bytes:
    import pymupdf

    doc = pymupdf.open()
    page = doc.new_page()
    y = 72
    for line in text.splitlines():
        page.insert_text((72, y), line)
        y += 16
    data = doc.tobytes()
    doc.close()
    return data
