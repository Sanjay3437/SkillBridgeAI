"""API v1 router aggregation."""

from fastapi import APIRouter

from app.api.v1 import analyses, auth, dashboard, jobs, resumes, roadmaps, users

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(resumes.router)
api_router.include_router(jobs.router)
api_router.include_router(analyses.router)
api_router.include_router(roadmaps.router)
api_router.include_router(dashboard.router)


@api_router.get("/health", tags=["health"])
async def health() -> dict[str, str]:
    return {"status": "ok"}
