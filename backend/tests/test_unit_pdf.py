"""Unit tests for PDF validation and text extraction."""

import pymupdf
import pytest

from app.services.resume_service import ResumeValidationError, extract_pdf_text, validate_pdf


def make_text_pdf(text: str) -> bytes:
    doc = pymupdf.open()
    page = doc.new_page()
    page.insert_text((72, 72), text)
    data = doc.tobytes()
    doc.close()
    return data


def make_blank_pdf() -> bytes:
    doc = pymupdf.open()
    doc.new_page()
    data = doc.tobytes()
    doc.close()
    return data


def test_validate_rejects_non_pdf():
    with pytest.raises(ResumeValidationError, match="not a valid PDF"):
        validate_pdf(b"hello world", "resume.pdf")


def test_validate_rejects_wrong_extension():
    with pytest.raises(ResumeValidationError, match="Only PDF"):
        validate_pdf(b"%PDF-1.4 fake", "resume.docx")


def test_extract_text_from_text_pdf():
    text = extract_pdf_text(
        make_text_pdf("Python developer with FastAPI and PostgreSQL experience")
    )
    assert "Python developer" in text


def test_blank_pdf_is_rejected_as_scanned():
    with pytest.raises(ResumeValidationError, match="scanned or image-only"):
        extract_pdf_text(make_blank_pdf())


def test_page_limit_is_enforced(monkeypatch):
    from app.core.config import settings

    monkeypatch.setattr(settings, "max_resume_pages", 0)
    with pytest.raises(ResumeValidationError, match="page limit"):
        extract_pdf_text(make_text_pdf("Hello"))
