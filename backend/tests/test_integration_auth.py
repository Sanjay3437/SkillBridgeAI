"""Integration tests for authentication and session lifecycle."""

from tests.conftest import auth_headers, register


async def test_register_returns_tokens_and_user(client):
    data = await register(client)
    assert data["user"]["email"] == "user@example.com"
    assert data["tokens"]["access_token"]
    assert data["tokens"]["refresh_token"]


async def test_duplicate_email_is_rejected(client):
    await register(client)
    response = await client.post(
        "/api/v1/auth/register",
        json={"email": "user@example.com", "password": "password123"},
    )
    assert response.status_code == 409


async def test_login_with_wrong_password_is_rejected(client):
    await register(client)
    response = await client.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "wrong-password"},
    )
    assert response.status_code == 401


async def test_login_returns_user_and_tokens(client):
    await register(client)
    response = await client.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "password123"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["user"]["email"] == "user@example.com"
    assert data["tokens"]["access_token"]
    assert data["tokens"]["refresh_token"]


async def test_me_requires_token(client):
    response = await client.get("/api/v1/users/me")
    assert response.status_code == 401


async def test_me_returns_current_user(client):
    data = await register(client)
    response = await client.get("/api/v1/users/me", headers=auth_headers(data))
    assert response.status_code == 200
    assert response.json()["email"] == "user@example.com"


async def test_refresh_rotates_token(client):
    data = await register(client)
    old_refresh = data["tokens"]["refresh_token"]

    response = await client.post("/api/v1/auth/refresh", json={"refresh_token": old_refresh})
    assert response.status_code == 200
    new_tokens = response.json()
    assert new_tokens["refresh_token"] != old_refresh

    # The rotated token cannot be reused.
    replay = await client.post("/api/v1/auth/refresh", json={"refresh_token": old_refresh})
    assert replay.status_code == 401


async def test_logout_revokes_session(client):
    data = await register(client)
    headers = auth_headers(data)

    logout = await client.post(
        "/api/v1/auth/logout", json={"refresh_token": data["tokens"]["refresh_token"]}
    )
    assert logout.status_code == 204

    response = await client.get("/api/v1/users/me", headers=headers)
    assert response.status_code == 401


async def test_refresh_rejects_garbage(client):
    response = await client.post("/api/v1/auth/refresh", json={"refresh_token": "not-a-token"})
    assert response.status_code == 401
