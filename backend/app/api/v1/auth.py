"""Authentication endpoints: register, login, refresh, logout."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_current_user
from app.core.config import settings
from app.core.security import (
    create_access_token,
    generate_refresh_token_string,
    hash_password,
    hash_token,
    verify_password,
)
from app.db.session import get_db
from app.models.user import RefreshSession, User
from app.schemas.auth import (
    AuthResponse,
    LoginRequest,
    LogoutRequest,
    RefreshRequest,
    RegisterRequest,
    RegisterResponse,
    TokenPair,
    UserPublic,
)

router = APIRouter(prefix="/auth", tags=["auth"])


def _token_pair(user_id: uuid.UUID, session_id: uuid.UUID) -> TokenPair:
    return TokenPair(
        access_token=create_access_token(user_id, session_id),
        refresh_token=generate_refresh_token_string(),
        expires_in=settings.jwt_access_ttl_minutes * 60,
    )


async def _create_session(db: AsyncSession, user_id: uuid.UUID) -> tuple[RefreshSession, str]:
    opaque = generate_refresh_token_string()
    session = RefreshSession(
        user_id=user_id,
        token_hash=hash_token(opaque),
        expires_at=datetime.now(UTC) + timedelta(days=settings.jwt_refresh_ttl_days),
    )
    db.add(session)
    await db.flush()
    return session, opaque


@router.post("/register", response_model=RegisterResponse, status_code=status.HTTP_201_CREATED)
async def register(
    payload: RegisterRequest, db: AsyncSession = Depends(get_db)
) -> RegisterResponse:
    existing = await db.execute(select(User).where(User.email == payload.email.lower()))
    if existing.scalar_one_or_none() is not None:
        raise HTTPException(status_code=409, detail="Email is already registered")

    user = User(email=payload.email.lower(), password_hash=hash_password(payload.password))
    db.add(user)
    await db.flush()

    session, refresh = await _create_session(db, user.id)
    await db.commit()
    await db.refresh(user)

    tokens = TokenPair(
        access_token=create_access_token(user.id, session.id),
        refresh_token=refresh,
        expires_in=settings.jwt_access_ttl_minutes * 60,
    )
    return RegisterResponse(user=UserPublic.model_validate(user), tokens=tokens)


@router.post("/login", response_model=AuthResponse)
async def login(payload: LoginRequest, db: AsyncSession = Depends(get_db)) -> AuthResponse:
    result = await db.execute(select(User).where(User.email == payload.email.lower()))
    user = result.scalar_one_or_none()
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    session, refresh = await _create_session(db, user_id=user.id)
    await db.commit()
    await db.refresh(user)
    return AuthResponse(
        user=UserPublic.model_validate(user),
        tokens=TokenPair(
            access_token=create_access_token(user.id, session.id),
            refresh_token=refresh,
            expires_in=settings.jwt_access_ttl_minutes * 60,
        ),
    )


@router.post("/refresh", response_model=TokenPair)
async def refresh(payload: RefreshRequest, db: AsyncSession = Depends(get_db)) -> TokenPair:
    token_hash = hash_token(payload.refresh_token)
    result = await db.execute(select(RefreshSession).where(RefreshSession.token_hash == token_hash))
    session = result.scalar_one_or_none()
    if session is None or session.revoked_at is not None:
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    if session.expires_at.replace(tzinfo=UTC) < datetime.now(UTC):
        raise HTTPException(status_code=401, detail="Refresh token expired")

    # Rotate: revoke the old session, issue a new one.
    session.revoked_at = datetime.now(UTC)
    new_session, new_refresh = await _create_session(db, session.user_id)
    await db.commit()

    return TokenPair(
        access_token=create_access_token(session.user_id, new_session.id),
        refresh_token=new_refresh,
        expires_in=settings.jwt_access_ttl_minutes * 60,
    )


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(payload: LogoutRequest, db: AsyncSession = Depends(get_db)) -> Response:
    token_hash = hash_token(payload.refresh_token)
    result = await db.execute(select(RefreshSession).where(RefreshSession.token_hash == token_hash))
    session = result.scalar_one_or_none()
    if session is not None and session.revoked_at is None:
        session.revoked_at = datetime.now(UTC)
        await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/me", response_model=UserPublic)
async def me(user: User = Depends(get_current_user)) -> UserPublic:
    return UserPublic.model_validate(user)
