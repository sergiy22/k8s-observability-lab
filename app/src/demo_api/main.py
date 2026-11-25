"""demo-api: a tiny HTTP service instrumented with Prometheus metrics.

It exists to give the monitoring stack something realistic to observe:
request rate, error rate and latency (the RED method), plus build info.
Error rate and latency can be tuned with environment variables so that
alerts and dashboards can be demonstrated on demand.
"""

from __future__ import annotations

import os
import random
import time

from flask import Flask, Response, g, jsonify, request
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    CollectorRegistry,
    Counter,
    Gauge,
    Histogram,
    generate_latest,
)

APP_NAME = "demo-api"


def _float_env(name: str, default: float) -> float:
    try:
        return float(os.environ.get(name, default))
    except ValueError:
        return default


def create_app(
    error_rate: float | None = None,
    max_latency_ms: float | None = None,
    registry: CollectorRegistry | None = None,
) -> Flask:
    """Application factory.

    A dedicated registry per app instance keeps tests isolated from each other.
    """
    app = Flask(__name__)

    error_rate = _float_env("ERROR_RATE", 0.02) if error_rate is None else error_rate
    max_latency_ms = (
        _float_env("MAX_LATENCY_MS", 250.0) if max_latency_ms is None else max_latency_ms
    )
    error_rate = min(max(error_rate, 0.0), 1.0)
    max_latency_ms = max(max_latency_ms, 0.0)

    registry = registry or CollectorRegistry()
    version = os.environ.get("APP_VERSION", "dev")

    requests_total = Counter(
        "http_requests_total",
        "Total HTTP requests handled.",
        ["method", "endpoint", "status"],
        registry=registry,
    )
    request_duration = Histogram(
        "http_request_duration_seconds",
        "HTTP request latency in seconds.",
        ["method", "endpoint"],
        buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0),
        registry=registry,
    )
    in_flight = Gauge(
        "http_requests_in_flight",
        "HTTP requests currently being served.",
        registry=registry,
    )
    build_info = Gauge(
        "app_build_info",
        "Build information, value is always 1.",
        ["app", "version"],
        registry=registry,
    )
    build_info.labels(app=APP_NAME, version=version).set(1)

    # Probes and the metrics endpoint are not business traffic.
    untracked = {"/metrics", "/healthz", "/readyz"}

    @app.before_request
    def _start_timer() -> None:
        g.start = time.perf_counter()
        if request.path not in untracked:
            in_flight.inc()

    @app.after_request
    def _record(response: Response) -> Response:
        if request.path in untracked:
            return response
        in_flight.dec()
        # Use the route template, not the raw path, to keep label cardinality bounded.
        endpoint = request.url_rule.rule if request.url_rule else "unmatched"
        elapsed = time.perf_counter() - g.start
        request_duration.labels(request.method, endpoint).observe(elapsed)
        requests_total.labels(request.method, endpoint, str(response.status_code)).inc()
        return response

    @app.get("/")
    def index():
        return jsonify(app=APP_NAME, version=version, docs=["/api/orders", "/metrics"])

    @app.get("/healthz")
    def healthz():
        return jsonify(status="ok")

    @app.get("/readyz")
    def readyz():
        return jsonify(status="ready")

    @app.get("/api/orders")
    def orders():
        if max_latency_ms:
            time.sleep(random.uniform(0, max_latency_ms) / 1000.0)
        if random.random() < error_rate:
            return jsonify(error="simulated upstream failure"), 500
        items = [
            {"id": i, "sku": f"SKU-{random.randint(1000, 9999)}", "qty": random.randint(1, 5)}
            for i in range(1, 4)
        ]
        return jsonify(orders=items)

    @app.get("/metrics")
    def metrics():
        return Response(generate_latest(registry), mimetype=CONTENT_TYPE_LATEST)

    return app


app = create_app()
