"""Skill-gap analysis endpoints."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.v1.deps import get_current_user
from app.db.session import get_db
from app.models.analysis import Analysis
from app.models.roadmap import Roadmap, RoadmapTask
from app.models.user import User
from app.schemas.analysis import (
    AnalysisCreate,
    AnalysisListOut,
    AnalysisOut,
    AnalysisSummaryOut,
    CoverageOut,
    MatchedSkillOut,
    MissingSkillOut,
    RoadmapOut,
    RoadmapTaskOut,
)
from app.services.analysis_service import (
    AnalysisError,
    create_analysis,
    get_analysis_for_user,
    list_analyses_for_user,
)
from app.services.roadmap_service import RoadmapError, create_roadmap, get_roadmap_by_analysis
from app.worker import run_worker_once

router = APIRouter(prefix="/analyses", tags=["analyses"])


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


def _to_analysis_out(analysis: Analysis) -> AnalysisOut:
    matched: list[MatchedSkillOut] = []
    missing: list[MissingSkillOut] = []
    related: list[MissingSkillOut] = []

    for gap in analysis.gaps:
        if gap.match_status == "matched":
            matched.append(
                MatchedSkillOut(
                    skill=gap.skill.canonical_name,
                    evidence=gap.evidence_text,
                    confidence=1.0,
                )
            )
        elif gap.match_status == "related":
            related.append(
                MissingSkillOut(
                    skill=gap.skill.canonical_name,
                    priority=gap.priority,
                    reason=gap.reason,
                    status="related",
                )
            )
        else:
            missing.append(
                MissingSkillOut(
                    skill=gap.skill.canonical_name,
                    priority=gap.priority,
                    reason=gap.reason,
                    status="not_evidenced",
                )
            )

    required_gaps = [
        gap
        for gap in analysis.gaps
        if gap.priority in {"high", "medium"}
    ]
    matched_required = sum(1 for gap in required_gaps if gap.match_status == "matched")
    coverage = None
    if required_gaps:
        coverage = CoverageOut(
            matched_required=matched_required,
            total_required=len(required_gaps),
            percentage=float(analysis.coverage) if analysis.coverage is not None else None,
        )

    return AnalysisOut(
        id=analysis.id,
        status=analysis.status,
        coverage=coverage,
        matched_skills=matched,
        missing_skills=missing,
        related_skills=related,
        model_version=analysis.model_version,
        error_message=analysis.error_message,
        created_at=analysis.created_at,
    )


@router.post("", response_model=AnalysisOut, status_code=status.HTTP_202_ACCEPTED)
async def start_analysis(
    payload: AnalysisCreate,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> AnalysisOut:
    try:
        analysis = await create_analysis(db, user.id, payload.resume_id, payload.job_id)
    except AnalysisError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    background_tasks.add_task(run_worker_once)
    return AnalysisOut(id=analysis.id, status=analysis.status, created_at=analysis.created_at)


@router.get("", response_model=AnalysisListOut)
async def list_analyses(
    db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)
) -> AnalysisListOut:
    analyses = await list_analyses_for_user(db, user.id)
    return AnalysisListOut(
        items=[AnalysisSummaryOut.model_validate(a) for a in analyses], total=len(analyses)
    )


@router.get("/{analysis_id}", response_model=AnalysisOut)
async def get_analysis(
    analysis_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> AnalysisOut:
    analysis = await get_analysis_for_user(db, analysis_id, user.id)
    if analysis is None:
        raise HTTPException(status_code=404, detail="Analysis not found")
    return _to_analysis_out(analysis)


@router.get("/{analysis_id}/roadmap", response_model=RoadmapOut)
async def get_roadmap_for_analysis(
    analysis_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> RoadmapOut:
    roadmap = await get_roadmap_by_analysis(db, analysis_id, user.id)
    if roadmap is None:
        raise HTTPException(status_code=404, detail="Roadmap not generated yet")
    return _to_roadmap_out(roadmap)


@router.post(
    "/{analysis_id}/roadmap",
    response_model=RoadmapOut,
    status_code=status.HTTP_201_CREATED,
)
async def generate_roadmap(
    analysis_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> RoadmapOut:
    analysis = await get_analysis_for_user(db, analysis_id, user.id)
    if analysis is None:
        raise HTTPException(status_code=404, detail="Analysis not found")
    try:
        roadmap = await create_roadmap(db, analysis)
    except RoadmapError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    loaded = await db.execute(
        select(Roadmap)
        .options(selectinload(Roadmap.tasks).selectinload(RoadmapTask.skill))
        .where(Roadmap.id == roadmap.id)
    )
    return _to_roadmap_out(loaded.scalar_one())
