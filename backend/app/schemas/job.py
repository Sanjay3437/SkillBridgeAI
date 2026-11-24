"""Job description schemas."""

import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class JobCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    company: str | None = Field(default=None, max_length=200)
    description: str = Field(min_length=30, max_length=50_000)


class JobSkillOut(BaseModel):
    skill: str
    required: bool
    importance: float = Field(ge=0, le=1)
    evidence: str | None = None


class JobOut(BaseModel):
    id: uuid.UUID
    title: str
    company: str | None
    status: str
    error_message: str | None = None
    created_at: datetime

    model_config = {"from_attributes": True}


class JobDetailOut(JobOut):
    description: str
    skills: list[JobSkillOut] = Field(default_factory=list)


class JobListOut(BaseModel):
    items: list[JobOut]
    total: int
