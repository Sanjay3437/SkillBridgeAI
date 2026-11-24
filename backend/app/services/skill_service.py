"""Skill taxonomy persistence helpers."""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.taxonomy import SkillEntry
from app.models.skill import Skill


async def get_or_create_skill(db: AsyncSession, entry: SkillEntry) -> Skill:
    result = await db.execute(select(Skill).where(Skill.canonical_name == entry.canonical_name))
    skill = result.scalar_one_or_none()
    if skill is None:
        skill = Skill(
            canonical_name=entry.canonical_name,
            taxonomy_id=entry.id,
            aliases=list(entry.aliases),
            category=entry.category,
            description=entry.description,
        )
        db.add(skill)
        await db.flush()
    else:
        # Keep taxonomy metadata fresh without clobbering user data.
        skill.taxonomy_id = entry.id
        skill.aliases = list(entry.aliases)
        skill.category = entry.category
    return skill


async def list_skills(db: AsyncSession) -> list[Skill]:
    result = await db.execute(select(Skill).order_by(Skill.canonical_name))
    return list(result.scalars().all())
