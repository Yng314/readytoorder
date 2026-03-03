from __future__ import annotations

from fastapi.testclient import TestClient

import app.main as backend_main


DEVICE_ID = "9f2f89f1-45f9-4d45-9249-7e0d67f8d5e1"
CLIENT_VERSION = "1.0.0"


def default_headers() -> dict[str, str]:
    return {
        "X-Device-ID": DEVICE_ID,
        "X-Client-Version": CLIENT_VERSION,
    }


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
