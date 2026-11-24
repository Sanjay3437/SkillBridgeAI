"""Database-backed worker for queued processing jobs.

The API enqueues rows with status='queued' and triggers `run_worker_once` in a
FastAPI background task. The same function can be run as a standalone loop:

    python -m app.worker
"""

from __future__ import annotations

import asyncio
import logging

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import SessionLocal
from app.models.analysis import Analysis
from app.models.job import Job
from app.models.resume import Resume
from app.services.analysis_service import process_analysis
from app.services.job_service import process_job
from app.services.resume_service import process_resume

logger = logging.getLogger("skillbridge.worker")

MAX_PER_RUN = 10


async def _claim_one(db: AsyncSession, model, status: str = "queued"):
    result = await db.execute(
        select(model)
        .where(model.status == status)
        .order_by(model.created_at)
        .limit(1)
        .with_for_update(skip_locked=True)
    )
    return result.scalar_one_or_none()


async def run_worker_once(db: AsyncSession | None = None) -> int:
    """Process up to MAX_PER_RUN queued items. Returns the number processed."""
    own_session = db is None
    session = db or SessionLocal()
    processed = 0
    try:
        for _ in range(MAX_PER_RUN):
            resume = await _claim_one(session, Resume)
            if resume is not None:
                await process_resume(session, resume)
                processed += 1
                continue
            job = await _claim_one(session, Job)
            if job is not None:
                await process_job(session, job)
                processed += 1
                continue
            analysis = await _claim_one(session, Analysis)
            if analysis is not None:
                await process_analysis(session, analysis)
                processed += 1
                continue
            break
    finally:
        if own_session:
            await session.close()
    return processed


async def worker_loop(interval_seconds: float = 2.0) -> None:
    logger.info("Worker loop started")
    while True:
        try:
            processed = await run_worker_once()
            if processed == 0:
                await asyncio.sleep(interval_seconds)
        except Exception:  # noqa: BLE001 - keep the loop alive
            logger.exception("Worker iteration failed")
            await asyncio.sleep(interval_seconds)


async def _drain() -> None:
    while await run_worker_once() > 0:
        pass


def main() -> None:
    import sys

    logging.basicConfig(level=logging.INFO)
    if "--drain" in sys.argv:
        asyncio.run(_drain())
    else:
        asyncio.run(worker_loop())


if __name__ == "__main__":
    main()
