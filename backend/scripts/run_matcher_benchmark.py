"""Benchmark runner for the SkillBridge AI deterministic gap matcher.

Reads datasets/evaluation/matcher_labels.yaml, runs classify_requirement for each
labeled pair, and reports precision/recall/f1 plus any mismatches.

Usage:
    cd backend
    .venv/bin/python scripts/run_matcher_benchmark.py
"""

from __future__ import annotations

import sys
from pathlib import Path

# Ensure both the repo root and the backend package are importable so that
# `app.ai.matcher` resolves whether the script is run from backend/ or the repo root.
REPO_ROOT = Path(__file__).resolve().parents[2]
BACKEND = REPO_ROOT / "backend"
for _root in (REPO_ROOT, BACKEND):
    if str(_root) not in sys.path:
        sys.path.insert(0, str(_root))

import yaml  # noqa: E402  (imported after path setup above)

from app.ai.matcher import JobRequirement, ResumeEvidence, classify_requirement  # noqa: E402
from app.ai.taxonomy import SkillEntry  # noqa: E402

LABELS_PATH = REPO_ROOT / "datasets" / "evaluation" / "matcher_labels.yaml"


def entry(skill_id: str, name: str, category: str = "Benchmark") -> SkillEntry:
    return SkillEntry(id=skill_id, canonical_name=name, category=category)


def run_benchmark() -> dict:
    raw = yaml.safe_load(LABELS_PATH.read_text(encoding="utf-8"))
    rows = raw["rows"]

    tp = fp = fn = 0
    mismatches: list[dict] = []

    for row in rows:
        req_id, resume_id, expected, _note = row
        requirement = JobRequirement(
            skill=entry(req_id, req_id.capitalize()), required=True
        )
        resume = [
            ResumeEvidence(skill=entry(resume_id, resume_id.capitalize()), evidence="x")
        ]
        got, _evidence = classify_requirement(requirement, resume)

        if got == "matched" and expected == "matched":
            tp += 1
        elif got == "related" and expected == "related":
            # related is treated as a positive prediction in this benchmark
            tp += 1
        elif got == "not_evidenced" and expected == "not_evidenced":
            tp += 1
        else:
            mismatches.append(
                {
                    "requirement": req_id,
                    "resume": resume_id,
                    "expected": expected,
                    "got": got,
                }
            )
            if expected != "not_evidenced" and got == "not_evidenced":
                fn += 1
            elif expected == "not_evidenced" and got != "not_evidenced":
                fp += 1
            else:
                fp += 1

    total = len(rows)
    precision = tp / (tp + fp) if (tp + fp) else 0.0
    recall = tp / (tp + fn) if (tp + fn) else 0.0
    f1 = 2 * precision * recall / (precision + recall) if (precision + recall) else 0.0

    return {
        "dataset": str(LABELS_PATH),
        "total": total,
        "tp": tp,
        "fp": fp,
        "fn": fn,
        "precision": round(precision, 4),
        "recall": round(recall, 4),
        "f1": round(f1, 4),
        "mismatches": mismatches,
    }


def main() -> int:
    report = run_benchmark()
    print(f"Benchmark dataset: {report['dataset']}")
    print(f"Total labeled pairs: {report['total']}")
    print(f"TP={report['tp']} FP={report['fp']} FN={report['fn']}")
    print(f"precision={report['precision']} recall={report['recall']} f1={report['f1']}")
    if report["mismatches"]:
        print("Mismatches:")
        for m in report["mismatches"]:
            print(f"  {m['requirement']} <- {m['resume']}: expected={m['expected']} got={m['got']}")
        return 1
    print("All labeled pairs classified correctly.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
