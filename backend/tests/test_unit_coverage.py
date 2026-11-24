"""Unit tests for the deterministic coverage metric."""

from app.ai.matcher import calculate_coverage, gap_priority


def test_coverage_three_of_five():
    assert calculate_coverage(3, 5) == 60.0


def test_coverage_no_requirements_is_undefined():
    assert calculate_coverage(0, 0) is None


def test_coverage_all_matched():
    assert calculate_coverage(5, 5) == 100.0


def test_priority_high_for_important_required_skill():
    assert gap_priority(required=True, importance=0.9) == "high"


def test_priority_medium_for_required_skill():
    assert gap_priority(required=True, importance=0.5) == "medium"


def test_priority_low_for_preferred_skill():
    assert gap_priority(required=False, importance=0.9) == "low"
