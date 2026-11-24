"""Personalized roadmap generation from analysis gaps."""

from __future__ import annotations

import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.analysis import Analysis, AnalysisGap
from app.models.resume import ProcessingStatus
from app.models.roadmap import Roadmap, RoadmapTask
from app.services.resources import get_resource

_PRIORITY_ORDER = {"high": 0, "medium": 1, "low": 2}


class RoadmapError(ValueError):
    pass


async def create_roadmap(db: AsyncSession, analysis: Analysis) -> Roadmap:
    if analysis.status != ProcessingStatus.completed.value:
        raise RoadmapError("Analysis is not complete")

    existing = await db.execute(
        select(Roadmap)
        .where(Roadmap.analysis_id == analysis.id)
        .order_by(Roadmap.created_at.desc())
    )
    roadmap = existing.scalars().first()
    if roadmap is not None:
        return roadmap

    roadmap = Roadmap(user_id=analysis.user_id, analysis_id=analysis.id)
    db.add(roadmap)
    await db.flush()

    gaps_result = await db.execute(
        select(AnalysisGap)
        .options(selectinload(AnalysisGap.skill))
        .where(
            AnalysisGap.analysis_id == analysis.id,
            AnalysisGap.match_status.in_(["not_evidenced", "related"]),
        )
    )
    gaps = list(gaps_result.scalars().all())
    gaps.sort(key=lambda gap: (_PRIORITY_ORDER.get(gap.priority, 3), gap.skill.canonical_name))

    for index, gap in enumerate(gaps):
        resource = get_resource(gap.skill.taxonomy_id or "", gap.skill.canonical_name)
        steps = "\n".join(f"- {step}" for step in resource.steps)
        db.add(
            RoadmapTask(
                roadmap_id=roadmap.id,
                skill_id=gap.skill_id,
                title=resource.title,
                description=f"Priority: {gap.priority}. Suggested steps:\n{steps}",
                resource_url=resource.url,
                status="pending",
                sort_order=index,
            )
        )

    await db.commit()
    await db.refresh(roadmap)
    return roadmap


async def get_roadmap_for_user(
    db: AsyncSession, roadmap_id: uuid.UUID, user_id: uuid.UUID
) -> Roadmap | None:
    result = await db.execute(
        select(Roadmap)
        .options(selectinload(Roadmap.tasks).selectinload(RoadmapTask.skill))
        .where(Roadmap.id == roadmap_id, Roadmap.user_id == user_id)
    )
    return result.scalar_one_or_none()


async def get_roadmap_by_analysis(
    db: AsyncSession, analysis_id: uuid.UUID, user_id: uuid.UUID
) -> Roadmap | None:
    result = await db.execute(
        select(Roadmap)
        .options(selectinload(Roadmap.tasks).selectinload(RoadmapTask.skill))
        .where(Roadmap.analysis_id == analysis_id, Roadmap.user_id == user_id)
        .order_by(Roadmap.created_at.desc())
    )
    return result.scalars().first()


async def update_task_status(
    db: AsyncSession, task: RoadmapTask, status: str
) -> RoadmapTask:
    task.status = status
    await db.commit()
    await db.refresh(task)
    return task
