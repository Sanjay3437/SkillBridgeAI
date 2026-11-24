"""Structured skill extraction: LLM providers plus a deterministic mock.

The mock extractor is a first-class provider: it keeps the whole pipeline
testable and demoable with zero network access, and it implements the
blueprint's "build the deterministic engine first" guidance.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass

import httpx
from pydantic import BaseModel, Field, ValidationError

from app.ai.taxonomy import SkillTaxonomy, get_taxonomy, normalize_term
from app.core.config import settings

_SENTENCE_RE = re.compile(r"(?<=[.!?])\s+|\n+")
PROMPT_PATH = "prompts/extract_skills.txt"


class ExtractedSkill(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    evidence: str = Field(min_length=1, max_length=600)
    confidence: float = Field(ge=0, le=1)


class SkillExtraction(BaseModel):
    skills: list[ExtractedSkill]


class ExtractionError(RuntimeError):
    pass


@dataclass(frozen=True)
class ExtractionResult:
    skills: list[ExtractedSkill]
    provider: str
    model_version: str


def _sentences(text: str) -> list[str]:
    return [part.strip() for part in _SENTENCE_RE.split(text) if part.strip()]


def verify_evidence(evidence: str, source_text: str) -> bool:
    """Evidence must be a verbatim (whitespace-normalized) span of the source."""
    source = normalize_term(source_text)
    candidate = normalize_term(evidence)
    if not candidate:
        return False
    return candidate in source


def _sentence_for(text: str, needle: str) -> str | None:
    target = normalize_term(needle)
    for sentence in _sentences(text):
        if target in normalize_term(sentence):
            return sentence[:600]
    return None


class MockExtractor:
    """Deterministic alias-based extraction used for offline dev, tests, and demo."""

    provider = "mock"
    model_version = "mock-taxonomy-v1"

    def __init__(self, taxonomy: SkillTaxonomy | None = None) -> None:
        self.taxonomy = taxonomy or get_taxonomy()

    def extract(self, text: str) -> list[ExtractedSkill]:
        skills: list[ExtractedSkill] = []
        for entry, alias in self.taxonomy.find_mentions(text):
            sentence = _sentence_for(text, alias) or alias
            skills.append(
                ExtractedSkill(
                    name=entry.canonical_name,
                    evidence=sentence,
                    confidence=(
                        0.9
                        if normalize_term(alias) == normalize_term(entry.canonical_name)
                        else 0.8
                    ),
                )
            )
        return skills


class LLMExtractor:
    """Provider-agnostic structured extraction. Output is validated and evidence-checked."""

    def __init__(self, provider: str | None = None) -> None:
        self.provider = (provider or settings.llm_provider).lower()
        self.model = settings.llm_model
        self.prompt = self._load_prompt()

    @staticmethod
    def _load_prompt() -> str:
        from pathlib import Path

        return (Path(__file__).parent / PROMPT_PATH).read_text(encoding="utf-8")

    def _chat(self, text: str) -> str:
        if not settings.llm_api_key:
            raise ExtractionError("LLM_API_KEY is not configured")
        if self.provider == "openai":
            response = httpx.post(
                "https://api.openai.com/v1/chat/completions",
                headers={"Authorization": f"Bearer {settings.llm_api_key}"},
                json={
                    "model": self.model,
                    "temperature": 0,
                    "response_format": {"type": "json_object"},
                    "messages": [
                        {"role": "system", "content": self.prompt},
                        {"role": "user", "content": text},
                    ],
                },
                timeout=settings.llm_timeout_seconds,
            )
            response.raise_for_status()
            return response.json()["choices"][0]["message"]["content"]
        if self.provider == "anthropic":
            response = httpx.post(
                "https://api.anthropic.com/v1/messages",
                headers={
                    "x-api-key": settings.llm_api_key,
                    "anthropic-version": "2023-06-01",
                },
                json={
                    "model": self.model,
                    "max_tokens": 2000,
                    "temperature": 0,
                    "system": self.prompt,
                    "messages": [{"role": "user", "content": text}],
                },
                timeout=settings.llm_timeout_seconds,
            )
            response.raise_for_status()
            return response.json()["content"][0]["text"]
        raise ExtractionError(f"Unsupported LLM provider: {self.provider}")

    def extract(self, text: str) -> list[ExtractedSkill]:
        raw = self._chat(text)
        try:
            payload = json.loads(raw)
            parsed = SkillExtraction.model_validate(payload)
        except (json.JSONDecodeError, ValidationError) as exc:
            raise ExtractionError(f"Invalid structured extraction: {exc}") from exc
        # Drop any claim whose evidence is not literally in the source.
        return [skill for skill in parsed.skills if verify_evidence(skill.evidence, text)]


def extract_skills(text: str, provider: str | None = None) -> ExtractionResult:
    chosen = (provider or settings.llm_provider).lower()
    if chosen == "mock":
        extractor = MockExtractor()
        return ExtractionResult(
            skills=extractor.extract(text),
            provider="mock",
            model_version=extractor.model_version,
        )
    llm = LLMExtractor(provider=chosen)
    return ExtractionResult(
        skills=llm.extract(text),
        provider=chosen,
        model_version=f"{chosen}:{llm.model}",
    )


__all__ = [
    "ExtractedSkill",
    "ExtractionError",
    "ExtractionResult",
    "LLMExtractor",
    "MockExtractor",
    "SkillExtraction",
    "extract_skills",
    "verify_evidence",
]
