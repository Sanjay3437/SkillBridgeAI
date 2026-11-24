"""Resume and resume-skill models."""

import uuid
from enum import StrEnum
from typing import TYPE_CHECKING

from sqlalchemy import CheckConstraint, ForeignKey, Numeric, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin

if TYPE_CHECKING:
    from app.models.skill import Skill
    from app.models.user import User


class ProcessingStatus(StrEnum):
    queued = "queued"
    processing = "processing"
    completed = "completed"
    failed = "failed"


class Resume(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "resumes"
    __table_args__ = (
        CheckConstraint(
            "status IN ('queued', 'processing', 'completed', 'failed')",
            name="status_valid",
        ),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    file_key: Mapped[str] = mapped_column(Text, nullable=False)
    original_filename: Mapped[str | None] = mapped_column(String(255), nullable=True)
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default=ProcessingStatus.queued.value, index=True
    )
    extracted_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)

    user: Mapped["User"] = relationship(back_populates="resumes")
    skills: Mapped[list["ResumeSkill"]] = relationship(
        back_populates="resume", cascade="all, delete-orphan"
    )


class ResumeSkill(Base, UUIDPrimaryKeyMixin):
    __tablename__ = "resume_skills"
    __table_args__ = (UniqueConstraint("resume_id", "skill_id", name="uq_resume_skill"),)

    resume_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("resumes.id", ondelete="CASCADE"), nullable=False, index=True
    )
    skill_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("skills.id", ondelete="CASCADE"), nullable=False, index=True
    )
    evidence_text: Mapped[str] = mapped_column(Text, nullable=False)
    confidence: Mapped[float] = mapped_column(Numeric(4, 3), nullable=False, default=0.0)

    resume: Mapped["Resume"] = relationship(back_populates="skills")
    skill: Mapped["Skill"] = relationship()
