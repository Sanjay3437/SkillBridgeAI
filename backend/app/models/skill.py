"""Canonical skill taxonomy model."""

from sqlalchemy import String, Text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, UUIDPrimaryKeyMixin


class Skill(Base, UUIDPrimaryKeyMixin):
    __tablename__ = "skills"

    canonical_name: Mapped[str] = mapped_column(
        String(200), unique=True, nullable=False, index=True
    )
    taxonomy_id: Mapped[str | None] = mapped_column(String(100), nullable=True, index=True)
    aliases: Mapped[list[str]] = mapped_column(JSONB, nullable=False, default=list)
    category: Mapped[str | None] = mapped_column(String(100), nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
