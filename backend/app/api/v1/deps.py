"""Shared FastAPI dependencies."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt import PyJWTError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import decode_token
from app.db.session import get_db
from app.models.user import RefreshSession, User

bearer_scheme = HTTPBearer(auto_error=False)


def _unauthorized(message: str = "Not authenticated") -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=message,
        headers={"WWW-Authenticate": "Bearer"},
    )


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    if credentials is None:
        raise _unauthorized()
    try:
        payload = decode_token(credentials.credentials)
    except PyJWTError as exc:
        raise _unauthorized("Invalid or expired token") from exc

    if payload.get("type") != "access":
        raise _unauthorized("Invalid token type")

    try:
        user_id = uuid.UUID(payload["sub"])
        session_id = uuid.UUID(payload["sid"])
    except (KeyError, ValueError) as exc:
        raise _unauthorized("Malformed token") from exc

    session = await db.get(RefreshSession, session_id)
    if session is None or session.revoked_at is not None:
        raise _unauthorized("Session revoked")
    if session.expires_at.replace(tzinfo=UTC) < datetime.now(UTC):
        raise _unauthorized("Session expired")

    user = await db.get(User, user_id)
    if user is None:
        raise _unauthorized("User not found")
    return user
