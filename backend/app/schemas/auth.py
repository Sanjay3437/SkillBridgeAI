"""Authentication request/response schemas."""

import uuid

from pydantic import BaseModel, EmailStr, Field


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=10)


class LogoutRequest(BaseModel):
    refresh_token: str = Field(min_length=10)


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class UserPublic(BaseModel):
    id: uuid.UUID
    email: EmailStr

    model_config = {"from_attributes": True}


class AuthResponse(BaseModel):
    user: UserPublic
    tokens: TokenPair


class RegisterResponse(AuthResponse):
    pass
