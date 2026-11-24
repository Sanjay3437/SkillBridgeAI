"""Resume upload, listing, detail, and deletion."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, BackgroundTasks, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_current_user
from app.core.config import settings
from app.db.session import get_db
from app.models.user import User
from app.schemas.resume import ExtractedSkillOut, ResumeDetailOut, ResumeListOut, ResumeOut
from app.services.resume_service import (
    ResumeValidationError,
    create_resume,
    delete_resume,
    get_resume_for_user,
    list_resumes_for_user,
)
from app.worker import run_worker_once

router = APIRouter(prefix="/resumes", tags=["resumes"])


@router.post("", response_model=ResumeOut, status_code=status.HTTP_202_ACCEPTED)
async def upload_resume(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> ResumeOut:
    if file.content_type not in {"application/pdf", "application/octet-stream"}:
        raise HTTPException(status_code=415, detail="Only PDF files are accepted")
    file_bytes = await file.read()
    if len(file_bytes) > settings.max_resume_bytes:
        raise HTTPException(status_code=413, detail="File is too large")
    try:
        resume = await create_resume(db, user.id, file_bytes, file.filename)
    except ResumeValidationError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    background_tasks.add_task(run_worker_once)
    return ResumeOut.model_validate(resume)


@router.get("", response_model=ResumeListOut)
async def list_resumes(
    db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)
) -> ResumeListOut:
    resumes = await list_resumes_for_user(db, user.id)
    return ResumeListOut(items=[ResumeOut.model_validate(r) for r in resumes], total=len(resumes))


@router.get("/{resume_id}", response_model=ResumeDetailOut)
async def get_resume(
    resume_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> ResumeDetailOut:
    resume = await get_resume_for_user(db, resume_id, user.id)
    if resume is None:
        raise HTTPException(status_code=404, detail="Resume not found")
    skills = [
        ExtractedSkillOut(
            skill=item.skill.canonical_name,
            evidence=item.evidence_text,
            confidence=float(item.confidence),
        )
        for item in resume.skills
    ]
    return ResumeDetailOut(
        id=resume.id,
        original_filename=resume.original_filename,
        status=resume.status,
        error_message=resume.error_message,
        created_at=resume.created_at,
        extracted_text=resume.extracted_text,
        skills=skills,
    )


@router.delete("/{resume_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_resume(
    resume_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> None:
    resume = await get_resume_for_user(db, resume_id, user.id)
    if resume is None:
        raise HTTPException(status_code=404, detail="Resume not found")
    await delete_resume(db, resume)
