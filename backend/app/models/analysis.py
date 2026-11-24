"""Analysis and analysis-gap models."""

import uuid
from enum import StrEnum
from typing import TYPE_CHECKING

from sqlalchemy import CheckConstraint, ForeignKey, Numeric, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin

if TYPE_CHECKING:
    from app.models.job import Job
    from app.models.resume import Resume
    from app.models.skill import Skill
    from app.models.user import User


class MatchStatus(StrEnum):
    matched = "matched"
    related = "related"
    not_evidenced = "not_evidenced"


class GapPriority(StrEnum):
    low = "low"
    medium = "medium"
    high = "high"


class Analysis(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "analyses"
    __table_args__ = (
        CheckConstraint(
            "status IN ('queued', 'processing', 'completed', 'failed')",
            name="status_valid",
        ),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    resume_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("resumes.id", ondelete="CASCADE"), nullable=False, index=True
    )
    job_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("jobs.id", ondelete="CASCADE"), nullable=False, index=True
    )
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="queued", index=True)
    coverage: Mapped[float | None] = mapped_column(Numeric(5, 2), nullable=True)
    model_version: Mapped[str | None] = mapped_column(String(100), nullable=True)
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)

    user: Mapped["User"] = relationship(back_populates="analyses")
    resume: Mapped["Resume"] = relationship()
    job: Mapped["Job"] = relationship()
    gaps: Mapped[list["AnalysisGap"]] = relationship(
        back_populates="analysis", cascade="all, delete-orphan"
    )


class AnalysisGap(Base, UUIDPrimaryKeyMixin):
    __tablename__ = "analysis_gaps"
    __table_args__ = (UniqueConstraint("analysis_id", "skill_id", name="uq_analysis_skill"),)

    analysis_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("analyses.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    skill_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("skills.id", ondelete="CASCADE"), nullable=False, index=True
    )
    match_status: Mapped[str] = mapped_column(String(20), nullable=False)
    priority: Mapped[str] = mapped_column(String(10), nullable=False, default="medium")
    reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    evidence_text: Mapped[str | None] = mapped_column(Text, nullable=True)

    analysis: Mapped["Analysis"] = relationship(back_populates="gaps")
    skill: Mapped["Skill"] = relationship()
