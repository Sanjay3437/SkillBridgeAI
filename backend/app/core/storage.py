"""Private file storage abstraction: local disk for dev, S3-compatible for prod."""

from __future__ import annotations

import uuid
from pathlib import Path
from typing import Protocol

from app.core.config import settings


class Storage(Protocol):
    def save(self, key: str, data: bytes) -> None: ...
    def read(self, key: str) -> bytes: ...
    def delete(self, key: str) -> None: ...


class LocalStorage:
    """Writes under STORAGE_LOCAL_DIR. Keys are opaque and never user-supplied."""

    def __init__(self, base_dir: Path | None = None) -> None:
        self.base_dir = base_dir or settings.storage_path
        self.base_dir.mkdir(parents=True, exist_ok=True)

    def _path(self, key: str) -> Path:
        # Defend against traversal even though keys are generated server-side.
        target = (self.base_dir / key).resolve()
        if not str(target).startswith(str(self.base_dir)):
            raise ValueError("Invalid storage key")
        return target

    def save(self, key: str, data: bytes) -> None:
        path = self._path(key)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def read(self, key: str) -> bytes:
        return self._path(key).read_bytes()

    def delete(self, key: str) -> None:
        path = self._path(key)
        if path.exists():
            path.unlink()


class S3Storage:
    """S3-compatible storage. Requires the optional `boto3` dependency."""

    def __init__(self) -> None:
        import boto3  # lazy import

        self.bucket = settings.storage_bucket
        self.client = boto3.client(
            "s3",
            endpoint_url=settings.storage_endpoint or None,
            aws_access_key_id=settings.storage_access_key,
            aws_secret_access_key=settings.storage_secret_key,
        )

    def save(self, key: str, data: bytes) -> None:
        self.client.put_object(Bucket=self.bucket, Key=key, Body=data)

    def read(self, key: str) -> bytes:
        response = self.client.get_object(Bucket=self.bucket, Key=key)
        return response["Body"].read()

    def delete(self, key: str) -> None:
        self.client.delete_object(Bucket=self.bucket, Key=key)


def get_storage() -> Storage:
    if settings.storage_backend == "s3":
        return S3Storage()
    return LocalStorage()


def new_resume_key(user_id: uuid.UUID) -> str:
    return f"resumes/{user_id}/{uuid.uuid4()}.pdf"


__all__ = ["LocalStorage", "S3Storage", "Storage", "get_storage", "new_resume_key"]
