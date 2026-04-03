from __future__ import annotations

from fastapi.testclient import TestClient
from sqlalchemy import delete

import app.main as backend_main
from app.models import (
    ClientErrorEvent,
    Dish,
    DishImage,
    GenerationJob,
    User,
    UserProfile,
    UserSwipeEvent,
)


DEVICE_ID = "9f2f89f1-45f9-4d45-9249-7e0d67f8d5e1"
CLIENT_VERSION = "1.0.0"
MOCK_IDENTITY_TOKEN = "mock.identity.token.with.sufficient.length"


def default_headers() -> dict[str, str]:
    return {
        "X-Device-ID": DEVICE_ID,
        "X-Client-Version": CLIENT_VERSION,
    }


def auth_headers(session_token: str) -> dict[str, str]:
    headers = default_headers()
    headers["Authorization"] = f"Bearer {session_token}"
    return headers


def test_missing_device_id_header_returns_structured_400() -> None:
    with TestClient(backend_main.app) as client:
        response = client.post("/v1/taste/analyze", json={})

    assert response.status_code == 400
    body = response.json()
    assert body["code"] == "invalid_header"
    assert "X-Device-ID" in body["message"]
    assert isinstance(body["request_id"], str) and body["request_id"]


def test_invalid_client_version_returns_structured_400() -> None:
    headers = {
        "X-Device-ID": DEVICE_ID,
        "X-Client-Version": "dev-build",
    }
    with TestClient(backend_main.app) as client:
        response = client.post("/v1/taste/analyze", json={}, headers=headers)

    assert response.status_code == 400
    body = response.json()
    assert body["code"] == "invalid_header"
    assert "X-Client-Version" in body["message"]


def test_rate_limit_returns_429(monkeypatch) -> None:
    backend_main.RATE_LIMIT_BUCKETS.clear()
    monkeypatch.setattr(backend_main, "RATE_LIMIT_REQUESTS", 1)

    async def fake_analyze(_req):
        return backend_main.AnalyzeResponse(
            summary="ok",
            avoid="ok",
            strategy="ok",
            source="mock",
        )

    monkeypatch.setattr(backend_main, "_analyze_with_gemini", fake_analyze)

    with TestClient(backend_main.app) as client:
        first = client.post("/v1/taste/analyze", json={}, headers=default_headers())
        second = client.post("/v1/taste/analyze", json={}, headers=default_headers())

    assert first.status_code == 200
    assert second.status_code == 429
    body = second.json()
    assert body["code"] == "rate_limited"
    assert isinstance(body["request_id"], str) and body["request_id"]


def test_upstream_error_keeps_structured_502(monkeypatch) -> None:
    backend_main.RATE_LIMIT_BUCKETS.clear()
    monkeypatch.setattr(backend_main, "RATE_LIMIT_REQUESTS", 20)

    async def fail_analyze(_req):
        raise RuntimeError("boom")

    monkeypatch.setattr(backend_main, "_analyze_with_gemini", fail_analyze)

    with TestClient(backend_main.app) as client:
        response = client.post("/v1/taste/analyze", json={}, headers=default_headers())

    assert response.status_code == 502
    body = response.json()
    assert body["code"] == "upstream_error"
    assert "Gemini analysis failed" in body["message"]


def test_health_does_not_expose_gemini_configured() -> None:
    with TestClient(backend_main.app) as client:
        response = client.get("/health")

    assert response.status_code == 200
    body = response.json()
    assert "gemini_configured" not in body
    assert "ready_dishes" in body


def test_taste_deck_returns_cached_dishes_without_auto_generation(monkeypatch) -> None:
    backend_main.RATE_LIMIT_BUCKETS.clear()
    monkeypatch.setattr(backend_main, "RATE_LIMIT_REQUESTS", 20)

    async def fail_if_generation_called(*_args, **_kwargs):
        raise AssertionError("deck generation should not run for app requests")

    monkeypatch.setattr(backend_main, "_generate_and_store_dishes", fail_if_generation_called)

    with backend_main.SessionLocal() as session:
        session.execute(delete(ClientErrorEvent))
        session.execute(delete(GenerationJob))
        session.execute(delete(Dish))
        session.execute(delete(DishImage))

        image = DishImage(
            provider="seed",
            model="test",
            prompt="seed image",
            mime_type="image/png",
            data_url="data:image/png;base64,AAAA",
        )
        session.add(image)
        session.flush()

        session.add_all(
            [
                Dish(
                    name="缓存菜一号",
                    subtitle="已有库存",
                    signals={},
                    category_tags={"cuisine": ["川菜"], "flavor": ["辣"], "ingredient": ["鸡肉"]},
                    tags_json={
                        "flavor": ["spicy", "savory"],
                        "ingredient": ["chicken", "peanut"],
                        "texture": ["tender"],
                        "cooking_method": ["stir_fried"],
                        "cuisine": ["sichuan"],
                        "course": ["main"],
                        "allergen": ["peanut"],
                    },
                    status="ready",
                    source="seed",
                    image_id=image.id,
                ),
                Dish(
                    name="缓存菜二号",
                    subtitle="已有库存",
                    signals={},
                    category_tags={"cuisine": ["日式"], "flavor": ["鲜"], "ingredient": ["海鲜"]},
                    tags_json={
                        "flavor": ["umami", "refreshing"],
                        "ingredient": ["fish"],
                        "texture": ["silky"],
                        "cooking_method": ["raw"],
                        "cuisine": ["japanese"],
                        "course": ["main"],
                        "allergen": ["fish"],
                    },
                    status="ready",
                    source="seed",
                    image_id=None,
                ),
            ]
        )
        session.commit()

    with TestClient(backend_main.app) as client:
        response = client.post("/v1/taste/deck", json={"count": 6}, headers=default_headers())

    assert response.status_code == 200
    body = response.json()
    assert body["source"] == "cache"
    assert len(body["dishes"]) == 2
    assert {dish["name"] for dish in body["dishes"]} == {"缓存菜一号", "缓存菜二号"}
    tags_by_name = {dish["name"]: dish["tags"] for dish in body["dishes"]}
    assert tags_by_name["缓存菜一号"]["flavor"] == ["spicy", "savory"]
    assert tags_by_name["缓存菜二号"]["allergen"] == ["fish"]

    image_payloads = {dish["name"]: dish["image_data_url"] for dish in body["dishes"]}
    assert image_payloads["缓存菜一号"] == "data:image/png;base64,AAAA"
    assert image_payloads["缓存菜二号"] is None


def test_apple_sign_in_creates_or_reuses_same_user(monkeypatch) -> None:
    backend_main.RATE_LIMIT_BUCKETS.clear()
    monkeypatch.setattr(backend_main, "RATE_LIMIT_REQUESTS", 20)

    def fake_verify(_identity_token: str) -> dict[str, str]:
        return {
            "sub": "apple-user-123",
            "email": "tester@example.com",
        }

    monkeypatch.setattr(backend_main, "_verify_apple_identity_token", fake_verify)

    with backend_main.SessionLocal() as session:
        session.execute(delete(UserSwipeEvent))
        session.execute(delete(UserProfile))
        session.execute(delete(User))
        session.commit()

    payload = {
        "identity_token": MOCK_IDENTITY_TOKEN,
        "display_name": "Young",
    }

    with TestClient(backend_main.app) as client:
        first = client.post("/v1/auth/apple/sign-in", json=payload, headers=default_headers())
        second = client.post("/v1/auth/apple/sign-in", json=payload, headers=default_headers())

    assert first.status_code == 200
    assert second.status_code == 200
    first_body = first.json()
    second_body = second.json()
    assert first_body["user"]["id"] == second_body["user"]["id"]
    assert first_body["user"]["apple_user_id"] == "apple-user-123"
    assert first_body["session_token"]


def test_profile_requires_auth_and_round_trips(monkeypatch) -> None:
    backend_main.RATE_LIMIT_BUCKETS.clear()
    monkeypatch.setattr(backend_main, "RATE_LIMIT_REQUESTS", 20)

    def fake_verify(_identity_token: str) -> dict[str, str]:
        return {
            "sub": "apple-user-456",
            "email": "profile@example.com",
        }

    monkeypatch.setattr(backend_main, "_verify_apple_identity_token", fake_verify)

    with TestClient(backend_main.app) as client:
        unauthorized = client.get("/v1/me/profile", headers=default_headers())
        assert unauthorized.status_code == 401

        sign_in = client.post(
                "/v1/auth/apple/sign-in",
                json={"identity_token": MOCK_IDENTITY_TOKEN, "display_name": "Profile User"},
                headers=default_headers(),
            )
        assert sign_in.status_code == 200
        token = sign_in.json()["session_token"]

        put_response = client.put(
            "/v1/me/profile",
            json={
                "taste_profile_json": {
                    "likeCountByTag": {"flavor:spicy": 3},
                    "dislikeCountByTag": {"ingredient:peanut": 1},
                    "exposureByTag": {"flavor:spicy": 5, "ingredient:peanut": 2},
                    "totalSwipes": 5,
                },
                "analysis_json": {
                    "summary": "偏爱辛辣口味",
                    "avoid": "少点花生",
                    "strategy": "优先看川菜和爆炒类",
                    "source": "mock",
                },
                "preferences_json": {"syncVersion": 1},
            },
            headers=auth_headers(token),
        )
        assert put_response.status_code == 200
        body = put_response.json()
        assert body["taste_profile_json"]["totalSwipes"] == 5
        assert body["analysis_json"]["summary"] == "偏爱辛辣口味"

        get_response = client.get("/v1/me/profile", headers=auth_headers(token))
        assert get_response.status_code == 200
        get_body = get_response.json()
        assert get_body["preferences_json"]["syncVersion"] == 1
        assert get_body["swipe_events"] == []


def test_swipe_batch_is_idempotent(monkeypatch) -> None:
    backend_main.RATE_LIMIT_BUCKETS.clear()
    monkeypatch.setattr(backend_main, "RATE_LIMIT_REQUESTS", 20)

    def fake_verify(_identity_token: str) -> dict[str, str]:
        return {"sub": "apple-user-789"}

    monkeypatch.setattr(backend_main, "_verify_apple_identity_token", fake_verify)

    event = {
        "id": "51640963-59e6-4d4f-bb7c-1c5d6c365b18",
        "dish_name": "宫保鸡丁",
        "action": "like",
        "dish_snapshot_json": {
            "name": "宫保鸡丁",
            "subtitle": "辣香开胃",
            "tags": {"flavor": ["spicy", "savory"], "ingredient": ["chicken", "peanut"]},
        },
        "created_at": "2026-03-31T00:00:00Z",
    }

    with TestClient(backend_main.app) as client:
        sign_in = client.post(
            "/v1/auth/apple/sign-in",
            json={"identity_token": MOCK_IDENTITY_TOKEN},
            headers=default_headers(),
        )
        token = sign_in.json()["session_token"]

        first = client.post("/v1/me/swipes/batch", json={"events": [event]}, headers=auth_headers(token))
        second = client.post("/v1/me/swipes/batch", json={"events": [event]}, headers=auth_headers(token))
        profile = client.get("/v1/me/profile", headers=auth_headers(token))

    assert first.status_code == 200
    assert second.status_code == 200
    assert first.json()["inserted_count"] == 1
    assert second.json()["inserted_count"] == 0
    assert profile.status_code == 200
    swipe_events = profile.json()["swipe_events"]
    assert len(swipe_events) == 1
    assert swipe_events[0]["dish_name"] == "宫保鸡丁"
