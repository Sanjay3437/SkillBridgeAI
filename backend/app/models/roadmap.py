"""Roadmap and roadmap-task models."""

import uuid
from enum import StrEnum
from typing import TYPE_CHECKING

from sqlalchemy import CheckConstraint, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin

if TYPE_CHECKING:
    from app.models.analysis import Analysis
    from app.models.skill import Skill
    from app.models.user import User


class TaskStatus(StrEnum):
    pending = "pending"
    in_progress = "in_progress"
    completed = "completed"


class Roadmap(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "roadmaps"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    analysis_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("analyses.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    user: Mapped["User"] = relationship(back_populates="roadmaps")
    analysis: Mapped["Analysis"] = relationship()
    tasks: Mapped[list["RoadmapTask"]] = relationship(
        back_populates="roadmap",
        cascade="all, delete-orphan",
        order_by="RoadmapTask.sort_order",
    )


class RoadmapTask(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "roadmap_tasks"
    __table_args__ = (
        CheckConstraint(
            "status IN ('pending', 'in_progress', 'completed')",
            name="status_valid",
        ),
    )

    roadmap_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("roadmaps.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    skill_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("skills.id", ondelete="SET NULL"), nullable=True, index=True
    )
    title: Mapped[str] = mapped_column(String(300), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    resource_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="pending")
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    roadmap: Mapped["Roadmap"] = relationship(back_populates="tasks")
    skill: Mapped["Skill"] = relationship()
