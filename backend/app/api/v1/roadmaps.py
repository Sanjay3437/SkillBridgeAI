"""Roadmap and roadmap-task endpoints."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.v1.deps import get_current_user
from app.db.session import get_db
from app.models.roadmap import Roadmap, RoadmapTask
from app.models.user import User
from app.schemas.analysis import RoadmapOut, RoadmapTaskOut, TaskUpdate
from app.services.roadmap_service import get_roadmap_for_user, update_task_status

router = APIRouter(tags=["roadmaps"])


def _to_roadmap_out(roadmap: Roadmap) -> RoadmapOut:
    return RoadmapOut(
        id=roadmap.id,
        analysis_id=roadmap.analysis_id,
        created_at=roadmap.created_at,
        tasks=[
            RoadmapTaskOut(
                id=task.id,
                title=task.title,
                description=task.description,
                resource_url=task.resource_url,
                status=task.status,
                sort_order=task.sort_order,
                skill=task.skill.canonical_name if task.skill else None,
            )
            for task in roadmap.tasks
        ],
    )


@router.get("/roadmaps/{roadmap_id}", response_model=RoadmapOut)
async def get_roadmap(
    roadmap_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> RoadmapOut:
    roadmap = await get_roadmap_for_user(db, roadmap_id, user.id)
    if roadmap is None:
        raise HTTPException(status_code=404, detail="Roadmap not found")
    return _to_roadmap_out(roadmap)


@router.patch("/roadmap-tasks/{task_id}", response_model=RoadmapTaskOut)
async def patch_task(
    task_id: uuid.UUID,
    payload: TaskUpdate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> RoadmapTaskOut:
    result = await db.execute(
        select(RoadmapTask)
        .join(Roadmap, Roadmap.id == RoadmapTask.roadmap_id)
        .options(selectinload(RoadmapTask.skill))
        .where(RoadmapTask.id == task_id, Roadmap.user_id == user.id)
    )
    task = result.scalar_one_or_none()
    if task is None:
        raise HTTPException(status_code=404, detail="Roadmap task not found")
    await update_task_status(db, task, payload.status)
    return RoadmapTaskOut(
        id=task.id,
        title=task.title,
        description=task.description,
        resource_url=task.resource_url,
        status=task.status,
        sort_order=task.sort_order,
        skill=task.skill.canonical_name if task.skill else None,
    )
