"""Job description processing and requirement extraction."""

from __future__ import annotations

import re
import uuid

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.ai.extractor import ExtractionError, extract_skills, verify_evidence
from app.ai.normalizer import get_normalizer
from app.ai.taxonomy import get_taxonomy
from app.models.job import Job, JobSkill
from app.models.resume import ProcessingStatus
from app.services.skill_service import get_or_create_skill

_PREFERRED_RE = re.compile(
    r"\b(preferred|nice[- ]to[- ]have|bonus|plus|desirable|advantage)\b", re.IGNORECASE
)


def is_preferred(evidence: str | None) -> bool:
    return bool(evidence and _PREFERRED_RE.search(evidence))


async def create_job(
    db: AsyncSession,
    user_id: uuid.UUID,
    title: str,
    company: str | None,
    description: str,
) -> Job:
    job = Job(
        user_id=user_id,
        title=title,
        company=company,
        description=description,
        status=ProcessingStatus.queued.value,
    )
    db.add(job)
    await db.commit()
    await db.refresh(job)
    return job


async def process_job(db: AsyncSession, job: Job) -> None:
    """Extract required/preferred skills from the job description."""
    job.status = ProcessingStatus.processing.value
    job.error_message = None
    await db.commit()

    try:
        extraction = extract_skills(job.description)
        normalizer = get_normalizer()
        taxonomy = get_taxonomy()

        await db.execute(delete(JobSkill).where(JobSkill.job_id == job.id))
        seen: set[uuid.UUID] = set()
        for extracted in extraction.skills:
            if not verify_evidence(extracted.evidence, job.description):
                continue
            normalized = normalizer.normalize(extracted.name)
            entry = normalized.entry if normalized else taxonomy.lookup(extracted.name)
            if entry is None:
                continue
            skill = await get_or_create_skill(db, entry)
            if skill.id in seen:
                continue
            seen.add(skill.id)
            preferred = is_preferred(extracted.evidence)
            db.add(
                JobSkill(
                    job_id=job.id,
                    skill_id=skill.id,
                    required=not preferred,
                    importance=0.4 if preferred else 0.7,
                    evidence_text=extracted.evidence,
                )
            )

        job.status = ProcessingStatus.completed.value
        await db.commit()
    except ExtractionError as exc:
        job.status = ProcessingStatus.failed.value
        job.error_message = str(exc)
        await db.commit()
    except Exception as exc:  # noqa: BLE001
        await db.rollback()
        job.status = ProcessingStatus.failed.value
        job.error_message = f"Processing failed: {exc}"
        await db.commit()


async def get_job_for_user(db: AsyncSession, job_id: uuid.UUID, user_id: uuid.UUID) -> Job | None:
    result = await db.execute(
        select(Job)
        .options(selectinload(Job.skills).selectinload(JobSkill.skill))
        .where(Job.id == job_id, Job.user_id == user_id)
    )
    return result.scalar_one_or_none()


async def list_jobs_for_user(db: AsyncSession, user_id: uuid.UUID) -> list[Job]:
    result = await db.execute(
        select(Job).where(Job.user_id == user_id).order_by(Job.created_at.desc())
    )
    return list(result.scalars().all())
