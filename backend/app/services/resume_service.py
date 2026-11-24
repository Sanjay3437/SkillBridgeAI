"""Resume validation, PDF text extraction, and processing."""

from __future__ import annotations

import uuid

import pymupdf
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.ai.extractor import ExtractionError, extract_skills, verify_evidence
from app.ai.normalizer import get_normalizer
from app.ai.taxonomy import get_taxonomy
from app.core.config import settings
from app.core.storage import get_storage, new_resume_key
from app.models.resume import ProcessingStatus, Resume, ResumeSkill
from app.services.skill_service import get_or_create_skill


class ResumeValidationError(ValueError):
    pass


def validate_pdf(file_bytes: bytes, filename: str | None) -> None:
    if len(file_bytes) > settings.max_resume_bytes:
        raise ResumeValidationError(
            f"File exceeds the {settings.max_resume_bytes // (1024 * 1024)} MB limit"
        )
    if not file_bytes.startswith(b"%PDF"):
        raise ResumeValidationError("File is not a valid PDF")
    if filename and not filename.lower().endswith(".pdf"):
        raise ResumeValidationError("Only PDF files are accepted")


def extract_pdf_text(file_bytes: bytes) -> str:
    try:
        with pymupdf.open(stream=file_bytes, filetype="pdf") as doc:
            if doc.page_count > settings.max_resume_pages:
                raise ResumeValidationError(
                    f"Resume exceeds the {settings.max_resume_pages}-page limit"
                )
            text = "\n".join(page.get_text("text") for page in doc).strip()
    except ResumeValidationError:
        raise
    except Exception as exc:
        raise ResumeValidationError("Could not read the PDF file") from exc

    if len(text) < 50:
        raise ResumeValidationError(
            "This PDF appears to be scanned or image-only. Please upload a text-based PDF."
        )
    return text


async def create_resume(
    db: AsyncSession,
    user_id: uuid.UUID,
    file_bytes: bytes,
    filename: str | None,
) -> Resume:
    validate_pdf(file_bytes, filename)
    key = new_resume_key(user_id)
    get_storage().save(key, file_bytes)
    resume = Resume(
        user_id=user_id,
        file_key=key,
        original_filename=filename,
        status=ProcessingStatus.queued.value,
    )
    db.add(resume)
    await db.commit()
    await db.refresh(resume)
    return resume


async def process_resume(db: AsyncSession, resume: Resume) -> None:
    """Extract text and skills. Safe to retry; replaces prior skill rows."""
    resume.status = ProcessingStatus.processing.value
    resume.error_message = None
    await db.commit()

    try:
        storage = get_storage()
        file_bytes = storage.read(resume.file_key)
        text = extract_pdf_text(file_bytes)
        resume.extracted_text = text

        extraction = extract_skills(text)
        taxonomy = get_taxonomy()
        normalizer = get_normalizer()

        await db.execute(delete(ResumeSkill).where(ResumeSkill.resume_id == resume.id))
        seen: set[uuid.UUID] = set()
        for extracted in extraction.skills:
            if not verify_evidence(extracted.evidence, text):
                continue  # unsupported claims are dropped
            normalized = normalizer.normalize(extracted.name)
            if normalized is None:
                entry = taxonomy.lookup(extracted.name)
                if entry is None:
                    continue
            else:
                entry = normalized.entry
            skill = await get_or_create_skill(db, entry)
            if skill.id in seen:
                continue
            seen.add(skill.id)
            db.add(
                ResumeSkill(
                    resume_id=resume.id,
                    skill_id=skill.id,
                    evidence_text=extracted.evidence,
                    confidence=extracted.confidence,
                )
            )

        resume.status = ProcessingStatus.completed.value
        await db.commit()
    except (ResumeValidationError, ExtractionError) as exc:
        resume.status = ProcessingStatus.failed.value
        resume.error_message = str(exc)
        await db.commit()
    except Exception as exc:  # noqa: BLE001 - surfaced via API status
        await db.rollback()
        resume.status = ProcessingStatus.failed.value
        resume.error_message = f"Processing failed: {exc}"
        await db.commit()


async def get_resume_for_user(
    db: AsyncSession, resume_id: uuid.UUID, user_id: uuid.UUID
) -> Resume | None:
    result = await db.execute(
        select(Resume)
        .options(selectinload(Resume.skills).selectinload(ResumeSkill.skill))
        .where(Resume.id == resume_id, Resume.user_id == user_id)
    )
    return result.scalar_one_or_none()


async def list_resumes_for_user(db: AsyncSession, user_id: uuid.UUID) -> list[Resume]:
    result = await db.execute(
        select(Resume).where(Resume.user_id == user_id).order_by(Resume.created_at.desc())
    )
    return list(result.scalars().all())


async def delete_resume(db: AsyncSession, resume: Resume) -> None:
    try:
        get_storage().delete(resume.file_key)
    except Exception:  # noqa: BLE001 - DB row removal must still proceed
        pass
    await db.delete(resume)
    await db.commit()
