"""Password hashing and JWT token helpers."""

import hashlib
import secrets
import uuid
from datetime import UTC, datetime, timedelta

import bcrypt
import jwt

from app.core.config import settings


def _prepare_password(password: str) -> bytes:
    # bcrypt has a 72-byte input limit; pre-hash long passwords with SHA-256.
    encoded = password.encode("utf-8")
    if len(encoded) > 72:
        return hashlib.sha256(encoded).hexdigest().encode("utf-8")
    return encoded


def hash_password(password: str) -> str:
    return bcrypt.hashpw(_prepare_password(password), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(_prepare_password(plain), hashed.encode("utf-8"))
    except ValueError:
        return False


def _now() -> datetime:
    return datetime.now(UTC)


def create_access_token(user_id: uuid.UUID, session_id: uuid.UUID) -> str:
    expire = _now() + timedelta(minutes=settings.jwt_access_ttl_minutes)
    payload = {
        "sub": str(user_id),
        "sid": str(session_id),
        "type": "access",
        "exp": expire,
        "iat": _now(),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def create_refresh_token(user_id: uuid.UUID, session_id: uuid.UUID) -> str:
    expire = _now() + timedelta(days=settings.jwt_refresh_ttl_days)
    payload = {
        "sub": str(user_id),
        "sid": str(session_id),
        "type": "refresh",
        "exp": expire,
        "iat": _now(),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def decode_token(token: str) -> dict:
    """Decode and validate a JWT. Raises jwt.PyJWTError on any problem."""
    return jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])


def generate_refresh_token_string() -> str:
    """Opaque token stored hashed in the DB (never returned to clients)."""
    return secrets.token_urlsafe(48)


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


__all__ = [
    "create_access_token",
    "create_refresh_token",
    "decode_token",
    "generate_refresh_token_string",
    "hash_password",
    "hash_token",
    "verify_password",
]
