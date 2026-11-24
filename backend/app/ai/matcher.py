"""Deterministic gap calculation and coverage metrics."""

from __future__ import annotations

from dataclasses import dataclass, field

from app.ai.taxonomy import SkillEntry

# Domain adjacency used for "related" classification. Deterministic and auditable.
# Declared one-way for readability, then symmetrized below.
_RELATED_GROUPS_ONE_WAY: dict[str, set[str]] = {
    "docker": {"kubernetes", "ci-cd", "linux", "terraform"},
    "kubernetes": {"docker", "terraform", "aws", "gcp", "azure", "ci-cd"},
    "react": {"nextjs", "react-native", "javascript", "typescript", "html", "css"},
    "nextjs": {"react", "javascript", "typescript", "nodejs"},
    "vue": {"javascript", "typescript", "html", "css"},
    "angular": {"typescript", "javascript", "html", "css"},
    "svelte": {"javascript", "typescript", "html", "css"},
    "fastapi": {"django", "flask", "python", "rest-api"},
    "django": {"fastapi", "flask", "python", "rest-api"},
    "flask": {"fastapi", "django", "python", "rest-api"},
    "nodejs": {"express", "javascript", "typescript", "rest-api"},
    "express": {"nodejs", "javascript", "rest-api"},
    "spring-boot": {"java", "rest-api", "microservices"},
    "postgresql": {"mysql", "sql", "sqlalchemy"},
    "mysql": {"postgresql", "sql"},
    "mongodb": {"sql", "redis"},
    "redis": {"mongodb", "message-queues"},
    "sqlalchemy": {"postgresql", "alembic", "python"},
    "alembic": {"sqlalchemy", "postgresql"},
    "aws": {"gcp", "azure", "terraform", "serverless"},
    "gcp": {"aws", "azure"},
    "azure": {"aws", "gcp"},
    "firebase": {"supabase", "serverless"},
    "supabase": {"firebase", "postgresql"},
    "pytorch": {"tensorflow", "deep-learning", "machine-learning", "python"},
    "tensorflow": {"pytorch", "deep-learning", "machine-learning"},
    "scikit-learn": {"machine-learning", "python", "pandas", "numpy"},
    "pandas": {"numpy", "data-analysis", "python"},
    "numpy": {"pandas", "data-analysis"},
    "llm": {"rag", "embeddings", "nlp"},
    "rag": {"llm", "embeddings", "pgvector"},
    "embeddings": {"rag", "llm", "nlp"},
    "jwt": {"oauth", "security"},
    "oauth": {"jwt", "security"},
    "ci-cd": {"github-actions", "docker", "testing"},
    "github-actions": {"ci-cd", "git", "testing"},
    "testing": {"pytest", "jest", "cypress", "playwright", "ci-cd"},
    "pytest": {"testing", "python"},
    "jest": {"testing", "javascript"},
    "cypress": {"testing", "playwright", "javascript"},
    "playwright": {"testing", "cypress"},
    "microservices": {"system-design", "message-queues", "grpc", "rest-api"},
    "system-design": {"microservices", "performance"},
    "graphql": {"rest-api"},
    "rest-api": {"graphql", "fastapi", "django", "express"},
    "message-queues": {"microservices", "redis"},
    "websockets": {"real-time", "nodejs"},
    "flutter": {"dart", "android", "ios"},
    "dart": {"flutter"},
    "react-native": {"react", "javascript", "typescript", "android", "ios"},
}


def _symmetric(groups: dict[str, set[str]]) -> dict[str, set[str]]:
    result: dict[str, set[str]] = {key: set(values) for key, values in groups.items()}
    for key, values in groups.items():
        for value in values:
            result.setdefault(value, set()).add(key)
    return result


RELATED_GROUPS: dict[str, set[str]] = _symmetric(_RELATED_GROUPS_ONE_WAY)


def calculate_coverage(matched: int, total: int) -> float | None:
    """Percentage of required skills with documented evidence.

    Returns None when there are no requirements (undefined ratio).
    """
    if total <= 0:
        return None
    return round(matched / total * 100, 2)


def gap_priority(required: bool, importance: float) -> str:
    if required and importance >= 0.7:
        return "high"
    if required:
        return "medium"
    return "low"


@dataclass(frozen=True)
class JobRequirement:
    skill: SkillEntry
    required: bool = True
    importance: float = 0.5
    evidence: str | None = None


@dataclass(frozen=True)
class ResumeEvidence:
    skill: SkillEntry
    evidence: str
    confidence: float = 0.0


@dataclass
class GapResult:
    matched: list[tuple[JobRequirement, ResumeEvidence]] = field(default_factory=list)
    related: list[tuple[JobRequirement, ResumeEvidence]] = field(default_factory=list)
    missing: list[JobRequirement] = field(default_factory=list)
    matched_required: int = 0
    total_required: int = 0
    coverage: float | None = None


def classify_requirement(
    requirement: JobRequirement,
    resume_skills: list[ResumeEvidence],
    normalizer=None,
) -> tuple[str, ResumeEvidence | None]:
    """Return (match_status, supporting_evidence)."""
    by_id = {item.skill.id: item for item in resume_skills}
    if requirement.skill.id in by_id:
        return "matched", by_id[requirement.skill.id]

    related_ids = RELATED_GROUPS.get(requirement.skill.id, set())
    for item in resume_skills:
        if item.skill.id in related_ids:
            return "related", item

    # Optional semantic fallback: never upgrades to "matched" without evidence.
    if normalizer is not None:
        for item in resume_skills:
            result = normalizer.normalize(item.skill.canonical_name)
            if result and result.entry.id == requirement.skill.id:
                return "related", item
    return "not_evidenced", None


def analyze_gaps(
    requirements: list[JobRequirement],
    resume_skills: list[ResumeEvidence],
    normalizer=None,
) -> GapResult:
    result = GapResult()
    for requirement in requirements:
        status, evidence = classify_requirement(requirement, resume_skills, normalizer)
        if status == "matched" and evidence is not None:
            result.matched.append((requirement, evidence))
            if requirement.required:
                result.matched_required += 1
        elif status == "related" and evidence is not None:
            result.related.append((requirement, evidence))
        else:
            result.missing.append(requirement)
        if requirement.required:
            result.total_required += 1
    result.coverage = calculate_coverage(result.matched_required, result.total_required)
    return result


__all__ = [
    "GapResult",
    "JobRequirement",
    "RELATED_GROUPS",
    "ResumeEvidence",
    "analyze_gaps",
    "calculate_coverage",
    "classify_requirement",
    "gap_priority",
]
