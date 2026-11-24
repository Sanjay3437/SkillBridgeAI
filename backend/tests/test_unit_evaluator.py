"""Unit tests for evaluation metrics."""

from app.ai.evaluator import MatchingEvaluation, precision_recall_f1, unsupported_skill_rate


def test_precision_recall_f1():
    metrics = precision_recall_f1(tp=6, fp=2, fn=2)
    assert metrics["precision"] == 0.75
    assert metrics["recall"] == 0.75
    assert metrics["f1"] == 0.75


def test_precision_recall_f1_zero_division():
    assert precision_recall_f1(0, 0, 0) == {"precision": 0.0, "recall": 0.0, "f1": 0.0}


def test_unsupported_skill_rate():
    extracted = ["React", "Docker", "Rust"]
    supported = ["React", "Docker"]
    assert unsupported_skill_rate(extracted, supported) == 0.3333


def test_unsupported_skill_rate_empty():
    assert unsupported_skill_rate([], []) == 0.0


def test_matching_evaluation_symmetric_lookup():
    evaluation = MatchingEvaluation(
        predictions={("React", "ReactJS"): True},
        labels=[("ReactJS", "React", True)],
    )
    report = evaluation.run()
    assert report["tp"] == 1
    assert report["fp"] == 0
    assert report["fn"] == 0
