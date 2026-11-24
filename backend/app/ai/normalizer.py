"""Skill normalization: alias lookup, fuzzy matching, optional embeddings."""

from __future__ import annotations

from dataclasses import dataclass
from difflib import SequenceMatcher
from functools import lru_cache

from app.ai.taxonomy import SkillEntry, SkillTaxonomy, get_taxonomy, normalize_term
from app.core.config import settings


@dataclass(frozen=True)
class NormalizationResult:
    entry: SkillEntry
    method: str  # "alias" | "fuzzy" | "embedding"
    score: float


def _fuzzy_score(query: str, candidates: list[str]) -> tuple[str, float]:
    best_name, best_score = "", 0.0
    for candidate in candidates:
        score = SequenceMatcher(None, query, normalize_term(candidate)).ratio()
        if score > best_score:
            best_name, best_score = candidate, score
    return best_name, best_score


class SkillNormalizer:
    def __init__(self, taxonomy: SkillTaxonomy | None = None) -> None:
        self.taxonomy = taxonomy or get_taxonomy()
        self._fuzzy_cutoff = 0.88
        self._embedder = None

    def normalize(self, name: str) -> NormalizationResult | None:
        entry = self.taxonomy.lookup(name)
        if entry:
            return NormalizationResult(entry=entry, method="alias", score=1.0)

        query = normalize_term(name)
        if not query:
            return None

        candidates: list[str] = []
        for item in self.taxonomy.entries:
            candidates.extend(item.all_names)
        best_name, best_score = _fuzzy_score(query, candidates)
        if best_score >= self._fuzzy_cutoff:
            entry = self.taxonomy.lookup(best_name)
            if entry:
                return NormalizationResult(entry=entry, method="fuzzy", score=best_score)

        if settings.embeddings_enabled:
            match = self._embedding_match(name)
            if match:
                return match
        return None

    # --- Optional semantic matching -------------------------------------
    def _load_embedder(self):
        if self._embedder is None:
            from sentence_transformers import SentenceTransformer  # lazy import

            self._embedder = SentenceTransformer(settings.embedding_model)
        return self._embedder

    def _embedding_match(self, name: str) -> NormalizationResult | None:
        try:
            import torch
            from sentence_transformers.util import cos_sim

            model = self._load_embedder()
            names = self.taxonomy.canonical_names
            vectors = model.encode([name, *names], convert_to_tensor=True)
            sims = cos_sim(vectors[0], vectors[1:])[0]
            best_idx = int(torch.argmax(sims))
            best_score = float(sims[best_idx])
            if best_score >= settings.embedding_match_threshold:
                entry = self.taxonomy.entries[best_idx]
                return NormalizationResult(entry=entry, method="embedding", score=best_score)
        except Exception:  # pragma: no cover - optional dependency / model download
            return None
        return None


@lru_cache
def get_normalizer() -> SkillNormalizer:
    return SkillNormalizer()


__all__ = ["NormalizationResult", "SkillNormalizer", "get_normalizer"]
