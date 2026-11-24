"""Offline evaluation metrics for the AI pipeline.

These functions are used by the evaluation benchmark and by unit tests.
They are deliberately independent of the database and the LLM provider.
"""

from __future__ import annotations

from dataclasses import dataclass, field


def precision_recall_f1(tp: int, fp: int, fn: int) -> dict[str, float]:
    precision = tp / (tp + fp) if (tp + fp) else 0.0
    recall = tp / (tp + fn) if (tp + fn) else 0.0
    f1 = 2 * precision * recall / (precision + recall) if (precision + recall) else 0.0
    return {
        "precision": round(precision, 4),
        "recall": round(recall, 4),
        "f1": round(f1, 4),
    }


@dataclass
class SetMetrics:
    tp: int = 0
    fp: int = 0
    fn: int = 0
    per_item: list[dict] = field(default_factory=list)

    def add(self, predicted: set[str], gold: set[str], item_id: str | None = None) -> None:
        tp = len(predicted & gold)
        fp = len(predicted - gold)
        fn = len(gold - predicted)
        self.tp += tp
        self.fp += fp
        self.fn += fn
        if item_id is not None:
            self.per_item.append(
                {
                    "id": item_id,
                    "predicted": sorted(predicted),
                    "gold": sorted(gold),
                    "tp": tp,
                    "fp": fp,
                    "fn": fn,
                }
            )

    def report(self) -> dict:
        return {
            **precision_recall_f1(self.tp, self.fp, self.fn),
            "tp": self.tp,
            "fp": self.fp,
            "fn": self.fn,
        }


def unsupported_skill_rate(extracted: list[str], supported: list[str]) -> float:
    """Share of extracted skills lacking verbatim evidence in the source."""
    if not extracted:
        return 0.0
    supported_set = set(supported)
    unsupported = [skill for skill in extracted if skill not in supported_set]
    return round(len(unsupported) / len(extracted), 4)


@dataclass
class MatchingEvaluation:
    """Evaluate labeled skill pairs (a, b, is_match) against predictions."""

    predictions: dict[tuple[str, str], bool]
    labels: list[tuple[str, str, bool]]
    metrics: SetMetrics = field(default_factory=SetMetrics)

    def run(self) -> dict:
        for a, b, label in self.labels:
            predicted = self.predictions.get((a, b), self.predictions.get((b, a), False))
            if predicted and label:
                self.metrics.tp += 1
            elif predicted and not label:
                self.metrics.fp += 1
            elif not predicted and label:
                self.metrics.fn += 1
        return self.metrics.report()


__all__ = [
    "MatchingEvaluation",
    "SetMetrics",
    "precision_recall_f1",
    "unsupported_skill_rate",
]
