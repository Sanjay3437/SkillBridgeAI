"""Curated skill taxonomy loading and alias indexing."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path

DEFAULT_TAXONOMY_PATH = (
    Path(__file__).resolve().parents[3] / "datasets" / "taxonomy" / "skills.json"
)

_PUNCT_RE = re.compile(r"[^\w\s+#./-]")
_SEP_RE = re.compile(r"[\s\-_/]+")


def normalize_term(value: str) -> str:
    """Lowercase, strip punctuation noise, collapse separators."""
    value = value.strip().lower()
    value = _PUNCT_RE.sub(" ", value)
    value = _SEP_RE.sub(" ", value)
    return value.strip()


@dataclass(frozen=True)
class SkillEntry:
    id: str
    canonical_name: str
    category: str | None
    aliases: tuple[str, ...] = ()
    description: str | None = None

    @property
    def all_names(self) -> tuple[str, ...]:
        return (self.canonical_name, *self.aliases)


@dataclass
class SkillTaxonomy:
    version: str
    entries: list[SkillEntry] = field(default_factory=list)
    _by_id: dict[str, SkillEntry] = field(default_factory=dict, init=False, repr=False)
    _alias_index: dict[str, SkillEntry] = field(default_factory=dict, init=False, repr=False)

    def __post_init__(self) -> None:
        for entry in self.entries:
            self._by_id[entry.id] = entry
            for name in entry.all_names:
                key = normalize_term(name)
                if key and key not in self._alias_index:
                    self._alias_index[key] = entry

    @classmethod
    def load(cls, path: Path | str | None = None) -> SkillTaxonomy:
        taxonomy_path = Path(path) if path else DEFAULT_TAXONOMY_PATH
        raw = json.loads(taxonomy_path.read_text(encoding="utf-8"))
        entries = [
            SkillEntry(
                id=item["id"],
                canonical_name=item["canonical_name"],
                category=item.get("category"),
                aliases=tuple(item.get("aliases", [])),
                description=item.get("description"),
            )
            for item in raw.get("skills", [])
        ]
        return cls(version=raw.get("version", "0.0.0"), entries=entries)

    def get(self, skill_id: str) -> SkillEntry | None:
        return self._by_id.get(skill_id)

    def lookup(self, name: str) -> SkillEntry | None:
        """Exact alias lookup after normalization."""
        return self._alias_index.get(normalize_term(name))

    def find_mentions(self, text: str) -> list[tuple[SkillEntry, str]]:
        """Find alias mentions in text, longest alias first to avoid partial overlaps."""
        normalized_text = f" {normalize_term(text)} "
        found: list[tuple[SkillEntry, str]] = []
        seen_ids: set[str] = set()
        aliases = sorted(self._alias_index.items(), key=lambda kv: len(kv[0]), reverse=True)
        for alias, entry in aliases:
            if entry.id in seen_ids:
                continue
            pattern = re.compile(rf"(?<![a-z0-9]){re.escape(alias)}(?![a-z0-9])")
            if pattern.search(normalized_text):
                found.append((entry, alias))
                seen_ids.add(entry.id)
        return found

    @property
    def canonical_names(self) -> list[str]:
        return [entry.canonical_name for entry in self.entries]


@lru_cache
def get_taxonomy() -> SkillTaxonomy:
    return SkillTaxonomy.load()


__all__ = ["SkillEntry", "SkillTaxonomy", "get_taxonomy", "normalize_term"]
