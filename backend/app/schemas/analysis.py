"""Analysis and roadmap schemas."""

import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class AnalysisCreate(BaseModel):
    resume_id: uuid.UUID
    job_id: uuid.UUID


class CoverageOut(BaseModel):
    matched_required: int
    total_required: int
    percentage: float | None


class MatchedSkillOut(BaseModel):
    skill: str
    evidence: str | None = None
    confidence: float = Field(ge=0, le=1)


class MissingSkillOut(BaseModel):
    skill: str
    priority: str
    reason: str | None = None
    status: str = "not_evidenced"


class AnalysisOut(BaseModel):
    id: uuid.UUID
    status: str
    coverage: CoverageOut | None = None
    matched_skills: list[MatchedSkillOut] = Field(default_factory=list)
    missing_skills: list[MissingSkillOut] = Field(default_factory=list)
    related_skills: list[MissingSkillOut] = Field(default_factory=list)
    model_version: str | None = None
    error_message: str | None = None
    created_at: datetime | None = None


class AnalysisSummaryOut(BaseModel):
    id: uuid.UUID
    status: str
    coverage: float | None = None
    created_at: datetime
    resume_id: uuid.UUID
    job_id: uuid.UUID

    model_config = {"from_attributes": True}


class AnalysisListOut(BaseModel):
    items: list[AnalysisSummaryOut]
    total: int


class RoadmapTaskOut(BaseModel):
    id: uuid.UUID
    title: str
    description: str | None = None
    resource_url: str | None = None
    status: str
    sort_order: int
    skill: str | None = None

    model_config = {"from_attributes": True}


class RoadmapOut(BaseModel):
    id: uuid.UUID
    analysis_id: uuid.UUID
    created_at: datetime
    tasks: list[RoadmapTaskOut] = Field(default_factory=list)

    model_config = {"from_attributes": True}


class TaskUpdate(BaseModel):
    status: str = Field(pattern="^(pending|in_progress|completed)$")


class DashboardOut(BaseModel):
    resumes: int
    jobs: int
    analyses: int
    roadmaps: int
    tasks_total: int
    tasks_completed: int
    completion_percentage: float
    latest_coverage: float | None = None
