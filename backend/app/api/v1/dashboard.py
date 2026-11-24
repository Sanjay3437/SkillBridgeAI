"""Progress dashboard summary."""

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_current_user
from app.db.session import get_db
from app.models.analysis import Analysis
from app.models.job import Job
from app.models.resume import Resume
from app.models.roadmap import Roadmap, RoadmapTask
from app.models.user import User
from app.schemas.analysis import DashboardOut

router = APIRouter(tags=["dashboard"])


@router.get("/dashboard", response_model=DashboardOut)
async def get_dashboard(
    db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)
) -> DashboardOut:
    resumes = await db.scalar(
        select(func.count()).select_from(Resume).where(Resume.user_id == user.id)
    )
    jobs = await db.scalar(select(func.count()).select_from(Job).where(Job.user_id == user.id))
    analyses = await db.scalar(
        select(func.count()).select_from(Analysis).where(Analysis.user_id == user.id)
    )
    roadmaps = await db.scalar(
        select(func.count()).select_from(Roadmap).where(Roadmap.user_id == user.id)
    )

    tasks_total = await db.scalar(
        select(func.count())
        .select_from(RoadmapTask)
        .join(Roadmap, Roadmap.id == RoadmapTask.roadmap_id)
        .where(Roadmap.user_id == user.id)
    )
    tasks_completed = await db.scalar(
        select(func.count())
        .select_from(RoadmapTask)
        .join(Roadmap, Roadmap.id == RoadmapTask.roadmap_id)
        .where(Roadmap.user_id == user.id, RoadmapTask.status == "completed")
    )
    latest_coverage = await db.scalar(
        select(Analysis.coverage)
        .where(Analysis.user_id == user.id, Analysis.status == "completed")
        .order_by(Analysis.created_at.desc())
        .limit(1)
    )

    total = int(tasks_total or 0)
    completed = int(tasks_completed or 0)
    percentage = round(completed / total * 100, 2) if total else 0.0

    return DashboardOut(
        resumes=int(resumes or 0),
        jobs=int(jobs or 0),
        analyses=int(analyses or 0),
        roadmaps=int(roadmaps or 0),
        tasks_total=total,
        tasks_completed=completed,
        completion_percentage=percentage,
        latest_coverage=float(latest_coverage) if latest_coverage is not None else None,
    )
