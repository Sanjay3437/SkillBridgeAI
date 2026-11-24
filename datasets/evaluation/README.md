# SkillBridge AI — Evaluation Benchmark

This directory holds the labeled datasets and benchmark harness for the
deterministic skill-gap matcher.

## Files

- `datasets/evaluation/matcher_labels.yaml`
  Labeled pairs `(requirement_skill_id, resume_skill_id, expected_status)` used
  to benchmark `app/ai/matcher.py`. Each row documents whether a resume skill
  evidences a required job skill as `matched`, `related`, or `not_evidenced`.

- `backend/scripts/run_matcher_benchmark.py`
  Runner that loads the labels, classifies each pair with `classify_requirement`,
  and reports precision/recall/f1 plus mismatches.

## How matching is benchmarked

The matcher classifies each required skill against resume evidence:

1. **matched** — resume has direct evidence (same taxonomy id) of the skill.
2. **related** — resume has adjacent experience from `RELATED_GROUPS`, a
   symmetrized domain graph. Related experience is surfaced separately and is
   **never** counted toward coverage or upgraded to `matched`.
3. **not_evidenced** — no direct or adjacent evidence.

Coverage = matched_required / total_required × 100, counting required skills
only. `not_evidenced` is never treated as proof of absence.

## Running the benchmark

From the `backend` directory:

```
.venv/bin/python scripts/run_matcher_benchmark.py
```

Expected result on the curated label set: all pairs classified correctly
(precision = recall = f1 = 1.0).

## Extending

Add rows to `matcher_labels.yaml` following the existing field order, then
re-run the runner. Any mismatch prints the requirement, resume skill, expected
status, and actual status.

## Design notes

- The taxonomy is versioned (`datasets/taxonomy/skills.json`, version 1.0.0).
- Aliases are normalized case-insensitively; longest-alias-first matching avoids
  partial overlaps (e.g. "react" won't swallow "react-native").
- `RELATED_GROUPS` is declared one-way for readability then symmetrized, so
  adjacency is bidirectional without duplicating entries.
- Evidence spans must be verbatim (whitespace-normalized) substrings of the
  source text; paraphrased claims are discarded.
