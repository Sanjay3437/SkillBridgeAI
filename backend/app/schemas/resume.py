"""Resume schemas."""

import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class ExtractedSkillOut(BaseModel):
    skill: str
    evidence: str
    confidence: float = Field(ge=0, le=1)


class ResumeOut(BaseModel):
    id: uuid.UUID
    original_filename: str | None
    status: str
    error_message: str | None = None
    created_at: datetime

    model_config = {"from_attributes": True}


class ResumeDetailOut(ResumeOut):
    extracted_text: str | None = None
    skills: list[ExtractedSkillOut] = Field(default_factory=list)


class ResumeListOut(BaseModel):
    items: list[ResumeOut]
    total: int
