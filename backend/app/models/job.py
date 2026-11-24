"""Job description and job-skill models."""

import uuid
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, CheckConstraint, ForeignKey, Numeric, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin

if TYPE_CHECKING:
    from app.models.skill import Skill
    from app.models.user import User


class Job(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "jobs"
    __table_args__ = (
        CheckConstraint(
            "status IN ('queued', 'processing', 'completed', 'failed')",
            name="status_valid",
        ),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    company: Mapped[str | None] = mapped_column(String(200), nullable=True)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="queued", index=True)
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)

    user: Mapped["User"] = relationship(back_populates="jobs")
    skills: Mapped[list["JobSkill"]] = relationship(
        back_populates="job", cascade="all, delete-orphan"
    )


class JobSkill(Base, UUIDPrimaryKeyMixin):
    __tablename__ = "job_skills"
    __table_args__ = (UniqueConstraint("job_id", "skill_id", name="uq_job_skill"),)

    job_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("jobs.id", ondelete="CASCADE"), nullable=False, index=True
    )
    skill_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("skills.id", ondelete="CASCADE"), nullable=False, index=True
    )
    required: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    importance: Mapped[float] = mapped_column(Numeric(4, 3), nullable=False, default=0.5)
    evidence_text: Mapped[str | None] = mapped_column(Text, nullable=True)

    job: Mapped["Job"] = relationship(back_populates="skills")
    skill: Mapped["Skill"] = relationship()
