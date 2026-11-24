"""Skill-gap analysis orchestration and persistence."""

from __future__ import annotations

import uuid

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.ai.matcher import (
    JobRequirement,
    ResumeEvidence,
    analyze_gaps,
    gap_priority,
)
from app.ai.normalizer import get_normalizer
from app.ai.taxonomy import SkillEntry, get_taxonomy
from app.models.analysis import Analysis, AnalysisGap
from app.models.job import Job, JobSkill
from app.models.resume import ProcessingStatus, Resume, ResumeSkill
from app.models.skill import Skill


class AnalysisError(ValueError):
    pass


def _to_entry(db_skill: Skill) -> SkillEntry:
    """Map a persisted Skill row back to its taxonomy entry (id-stable for matching)."""
    taxonomy = get_taxonomy()
    entry = taxonomy.get(db_skill.taxonomy_id) if db_skill.taxonomy_id else None
    if entry is not None:
        return entry
    return SkillEntry(
        id=db_skill.taxonomy_id or str(db_skill.id),
        canonical_name=db_skill.canonical_name,
        category=db_skill.category,
        aliases=tuple(db_skill.aliases or ()),
        description=db_skill.description,
    )


async def create_analysis(
    db: AsyncSession,
    user_id: uuid.UUID,
    resume_id: uuid.UUID,
    job_id: uuid.UUID,
) -> Analysis:
    resume = await db.get(Resume, resume_id)
    if resume is None or resume.user_id != user_id:
        raise AnalysisError("Resume not found")
    job = await db.get(Job, job_id)
    if job is None or job.user_id != user_id:
        raise AnalysisError("Job not found")
    if resume.status != ProcessingStatus.completed.value:
        raise AnalysisError("Resume is still processing")
    if job.status != ProcessingStatus.completed.value:
        raise AnalysisError("Job description is still processing")

    analysis = Analysis(
        user_id=user_id,
        resume_id=resume_id,
        job_id=job_id,
        status=ProcessingStatus.queued.value,
    )
    db.add(analysis)
    await db.commit()
    await db.refresh(analysis)
    return analysis


async def process_analysis(db: AsyncSession, analysis: Analysis) -> None:
    analysis.status = ProcessingStatus.processing.value
    analysis.error_message = None
    await db.commit()

    try:
        resume_result = await db.execute(
            select(Resume)
            .options(selectinload(Resume.skills).selectinload(ResumeSkill.skill))
            .where(Resume.id == analysis.resume_id)
        )
        resume = resume_result.scalar_one_or_none()
        job_result = await db.execute(
            select(Job)
            .options(selectinload(Job.skills).selectinload(JobSkill.skill))
            .where(Job.id == analysis.job_id)
        )
        job = job_result.scalar_one_or_none()
        if resume is None or job is None:
            raise AnalysisError("Resume or job no longer exists")

        requirements = [
            JobRequirement(
                skill=_to_entry(item.skill),
                required=item.required,
                importance=float(item.importance),
                evidence=item.evidence_text,
            )
            for item in job.skills
        ]
        evidence = [
            ResumeEvidence(
                skill=_to_entry(item.skill),
                evidence=item.evidence_text,
                confidence=float(item.confidence),
            )
            for item in resume.skills
        ]
        if not requirements:
            raise AnalysisError("No skills were extracted from the job description")

        # Taxonomy entries are used for matching; persisted rows are used for FKs.
        persisted_skill_id = {
            _to_entry(item.skill).id: item.skill_id for item in job.skills
        }

        result = analyze_gaps(requirements, evidence, normalizer=get_normalizer())

        await db.execute(delete(AnalysisGap).where(AnalysisGap.analysis_id == analysis.id))
        for requirement, evidence_item in result.matched:
            db.add(
                AnalysisGap(
                    analysis_id=analysis.id,
                    skill_id=persisted_skill_id[requirement.skill.id],
                    match_status="matched",
                    priority=gap_priority(requirement.required, requirement.importance),
                    reason="Supported by resume evidence",
                    evidence_text=evidence_item.evidence,
                )
            )
        for requirement, evidence_item in result.related:
            db.add(
                AnalysisGap(
                    analysis_id=analysis.id,
                    skill_id=persisted_skill_id[requirement.skill.id],
                    match_status="related",
                    priority=gap_priority(requirement.required, requirement.importance),
                    reason=(
                        f"Related experience: {evidence_item.skill.canonical_name} "
                        f"(evidence: {evidence_item.evidence[:200]})"
                    ),
                    evidence_text=evidence_item.evidence,
                )
            )
        for requirement in result.missing:
            db.add(
                AnalysisGap(
                    analysis_id=analysis.id,
                    skill_id=persisted_skill_id[requirement.skill.id],
                    match_status="not_evidenced",
                    priority=gap_priority(requirement.required, requirement.importance),
                    reason=(
                        "Required by the target role"
                        if requirement.required
                        else "Listed as a preferred skill"
                    ),
                )
            )

        analysis.coverage = result.coverage
        analysis.status = ProcessingStatus.completed.value
        analysis.model_version = "hybrid-taxonomy-v1"
        await db.commit()
    except AnalysisError as exc:
        analysis.status = ProcessingStatus.failed.value
        analysis.error_message = str(exc)
        await db.commit()
    except Exception as exc:  # noqa: BLE001
        await db.rollback()
        analysis.status = ProcessingStatus.failed.value
        analysis.error_message = f"Analysis failed: {exc}"
        await db.commit()


async def get_analysis_for_user(
    db: AsyncSession, analysis_id: uuid.UUID, user_id: uuid.UUID
) -> Analysis | None:
    result = await db.execute(
        select(Analysis)
        .options(selectinload(Analysis.gaps).selectinload(AnalysisGap.skill))
        .where(Analysis.id == analysis_id, Analysis.user_id == user_id)
    )
    return result.scalar_one_or_none()


async def list_analyses_for_user(db: AsyncSession, user_id: uuid.UUID) -> list[Analysis]:
    result = await db.execute(
        select(Analysis).where(Analysis.user_id == user_id).order_by(Analysis.created_at.desc())
    )
    return list(result.scalars().all())
