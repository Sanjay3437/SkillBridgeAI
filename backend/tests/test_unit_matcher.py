"""Unit tests for gap classification."""

from app.ai.matcher import (
    JobRequirement,
    ResumeEvidence,
    analyze_gaps,
    classify_requirement,
)
from app.ai.taxonomy import SkillEntry


def entry(skill_id: str, name: str, category: str = "Test") -> SkillEntry:
    return SkillEntry(id=skill_id, canonical_name=name, category=category)


def test_exact_match_requires_resume_evidence():
    requirement = JobRequirement(skill=entry("react", "React"))
    resume = [ResumeEvidence(skill=entry("react", "React"), evidence="Built a React dashboard")]

    status, evidence = classify_requirement(requirement, resume)

    assert status == "matched"
    assert evidence is not None
    assert evidence.evidence == "Built a React dashboard"


def test_related_skill_does_not_count_as_matched():
    requirement = JobRequirement(skill=entry("kubernetes", "Kubernetes"))
    resume = [ResumeEvidence(skill=entry("docker", "Docker"), evidence="Containerized services")]

    status, _ = classify_requirement(requirement, resume)

    assert status == "related"


def test_related_groups_are_symmetric():
    # FastAPI implies Python experience, but does not evidence the exact skill.
    requirement = JobRequirement(skill=entry("python", "Python"))
    resume = [ResumeEvidence(skill=entry("fastapi", "FastAPI"), evidence="Built FastAPI services")]

    status, _ = classify_requirement(requirement, resume)

    assert status == "related"


def test_missing_skill_is_not_evidenced():
    requirement = JobRequirement(skill=entry("rust", "Rust"))
    resume = [ResumeEvidence(skill=entry("python", "Python"), evidence="Wrote Python services")]

    status, evidence = classify_requirement(requirement, resume)

    assert status == "not_evidenced"
    assert evidence is None


def test_coverage_counts_only_required_skills():
    requirements = [
        JobRequirement(skill=entry("react", "React"), required=True),
        JobRequirement(skill=entry("docker", "Docker"), required=True),
        JobRequirement(skill=entry("kubernetes", "Kubernetes"), required=False),
    ]
    resume = [ResumeEvidence(skill=entry("react", "React"), evidence="React app")]

    result = analyze_gaps(requirements, resume)

    assert result.matched_required == 1
    assert result.total_required == 2
    assert result.coverage == 50.0
    assert len(result.missing) == 2


def test_empty_requirements_has_undefined_coverage():
    result = analyze_gaps([], [])

    assert result.coverage is None
