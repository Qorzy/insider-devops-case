import os

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_ping_returns_pong():
    response = client.get("/ping")
    assert response.status_code == 200
    assert response.json() == {"message": "pong"}


def test_healthz_returns_ok():
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_version_returns_name_and_sha():
    response = client.get("/version")
    assert response.status_code == 200
    body = response.json()
    expected_name = os.getenv("APP_NAME", "insider-case")
    assert body["name"] == expected_name
    assert "version" in body


def test_root_returns_endpoints_list():
    response = client.get("/")
    assert response.status_code == 200
    body = response.json()
    assert body["service"] == os.getenv("APP_NAME", "insider-case")
    assert "/ping" in body["endpoints"]
    assert "/metrics" in body["endpoints"]


def test_metrics_endpoint_exposes_prometheus_format():
    response = client.get("/metrics")
    assert response.status_code == 200
    # Prometheus exposition format starts with HELP/TYPE comments
    assert "# HELP" in response.text
    assert "# TYPE" in response.text


def test_ping_response_includes_request_id_header():
    response = client.get("/ping")
    assert "x-request-id" in response.headers
    assert len(response.headers["x-request-id"]) > 0