"""Job description CRUD."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.job import JobCreate, JobDetailOut, JobListOut, JobOut, JobSkillOut
from app.services.job_service import (
    create_job,
    get_job_for_user,
    list_jobs_for_user,
)
from app.worker import run_worker_once

router = APIRouter(prefix="/jobs", tags=["jobs"])


@router.post("", response_model=JobOut, status_code=status.HTTP_202_ACCEPTED)
async def add_job(
    payload: JobCreate,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> JobOut:
    job = await create_job(db, user.id, payload.title, payload.company, payload.description)
    background_tasks.add_task(run_worker_once)
    return JobOut.model_validate(job)


@router.get("", response_model=JobListOut)
async def list_jobs(
    db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)
) -> JobListOut:
    jobs = await list_jobs_for_user(db, user.id)
    return JobListOut(items=[JobOut.model_validate(j) for j in jobs], total=len(jobs))


@router.get("/{job_id}", response_model=JobDetailOut)
async def get_job(
    job_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> JobDetailOut:
    job = await get_job_for_user(db, job_id, user.id)
    if job is None:
        raise HTTPException(status_code=404, detail="Job not found")
    skills = [
        JobSkillOut(
            skill=item.skill.canonical_name,
            required=item.required,
            importance=float(item.importance),
            evidence=item.evidence_text,
        )
        for item in job.skills
    ]
    return JobDetailOut(
        id=job.id,
        title=job.title,
        company=job.company,
        status=job.status,
        error_message=job.error_message,
        created_at=job.created_at,
        description=job.description,
        skills=skills,
    )
