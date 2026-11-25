import pytest
from prometheus_client import CollectorRegistry

from demo_api.main import create_app


@pytest.fixture
def make_client():
    def _make(error_rate=0.0):
        app = create_app(error_rate=error_rate, max_latency_ms=0, registry=CollectorRegistry())
        app.config.update(TESTING=True)
        return app.test_client()

    return _make


def test_health_and_ready(make_client):
    client = make_client()
    assert client.get("/healthz").get_json() == {"status": "ok"}
    assert client.get("/readyz").get_json() == {"status": "ready"}


def test_index_reports_version(make_client, monkeypatch):
    monkeypatch.setenv("APP_VERSION", "1.2.3")
    client = make_client()
    body = client.get("/").get_json()
    assert body["app"] == "demo-api"
    assert body["version"] == "1.2.3"


def test_orders_success(make_client):
    resp = make_client(error_rate=0.0).get("/api/orders")
    assert resp.status_code == 200
    assert len(resp.get_json()["orders"]) == 3


def test_orders_failure_when_error_rate_is_one(make_client):
    resp = make_client(error_rate=1.0).get("/api/orders")
    assert resp.status_code == 500


def test_metrics_record_requests_by_route_and_status(make_client):
    client = make_client(error_rate=0.0)
    for _ in range(3):
        client.get("/api/orders")
    client.get("/does-not-exist")

    text = client.get("/metrics").get_data(as_text=True)
    assert 'http_requests_total{endpoint="/api/orders",method="GET",status="200"} 3.0' in text
    assert 'http_requests_total{endpoint="unmatched",method="GET",status="404"} 1.0' in text
    assert "http_request_duration_seconds_bucket" in text
    assert 'app_build_info{app="demo-api"' in text


def test_probes_and_metrics_are_not_counted(make_client):
    client = make_client()
    client.get("/healthz")
    client.get("/readyz")
    text = client.get("/metrics").get_data(as_text=True)
    assert 'endpoint="/healthz"' not in text
    assert 'endpoint="/metrics"' not in text


def test_in_flight_gauge_returns_to_zero(make_client):
    client = make_client()
    client.get("/api/orders")
    text = client.get("/metrics").get_data(as_text=True)
    assert "http_requests_in_flight 0.0" in text


@pytest.mark.parametrize("raw,expected", [("0.5", 0.5), ("2", 1.0), ("-1", 0.0), ("junk", 0.02)])
def test_error_rate_env_is_clamped(monkeypatch, raw, expected):
    monkeypatch.setenv("ERROR_RATE", raw)
    monkeypatch.setenv("MAX_LATENCY_MS", "0")
    # Indirect check: error_rate of 1.0 must always fail, 0.0 must never fail.
    app = create_app(registry=CollectorRegistry())
    client = app.test_client()
    if expected == 1.0:
        assert all(client.get("/api/orders").status_code == 500 for _ in range(5))
    if expected == 0.0:
        assert all(client.get("/api/orders").status_code == 200 for _ in range(5))
