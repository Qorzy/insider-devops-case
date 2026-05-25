"""
Tiny HTTP service for Insider One DevOps case study.
Three endpoints: /ping (liveness signal), /healthz (probe), /version (build info).
Plus /metrics (Prometheus) and /docs (OpenAPI UI).
"""
import json
import logging
import os
import sys
import uuid
from contextvars import ContextVar

from fastapi import FastAPI, Request
from prometheus_fastapi_instrumentator import Instrumentator
from pydantic import BaseModel

# --- Configuration via environment variables ---
# 12-factor: config from env, not hardcoded
BUILD_SHA = os.getenv("BUILD_SHA", "dev")
APP_NAME = os.getenv("APP_NAME", "insider-case")
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()

# --- Per-request context (asyncio-safe) ---
# Every HTTP request gets a short id; the JSON logger picks it up automatically.
request_id_var: ContextVar[str] = ContextVar("request_id", default="-")


# --- Structured JSON logging ---
class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "timestamp": self.formatTime(record, "%Y-%m-%dT%H:%M:%S%z"),
            "level": record.levelname,
            "msg": record.getMessage(),
            "logger": record.name,
            "request_id": request_id_var.get(),
        }
        return json.dumps(payload)


handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JsonFormatter())
logging.basicConfig(level=LOG_LEVEL, handlers=[handler], force=True)
logger = logging.getLogger(APP_NAME)


# --- App ---
app = FastAPI(title=APP_NAME)


# --- Middleware: attach a request_id to every request ---
@app.middleware("http")
async def add_request_id(request: Request, call_next):
    rid = request.headers.get("x-request-id") or uuid.uuid4().hex[:12]
    token = request_id_var.set(rid)
    try:
        response = await call_next(request)
        response.headers["x-request-id"] = rid
        return response
    finally:
        request_id_var.reset(token)


# --- Response models ---
class PingResponse(BaseModel):
    message: str


class HealthResponse(BaseModel):
    status: str


class VersionResponse(BaseModel):
    name: str
    version: str


class RootResponse(BaseModel):
    service: str
    version: str
    endpoints: list[str]


# --- Endpoints ---
@app.get("/", response_model=RootResponse, tags=["core"])
def root() -> dict:
    """Welcome page — quick orientation for anyone hitting the URL."""
    return {
        "service": APP_NAME,
        "version": BUILD_SHA,
        "endpoints": ["/ping", "/healthz", "/version", "/docs", "/metrics"],
    }


@app.get("/ping", response_model=PingResponse, tags=["core"])
def ping() -> dict:
    """Smoke test endpoint. Returns 'pong' if the process is alive."""
    logger.info("ping called")
    return {"message": "pong"}


@app.get("/healthz", response_model=HealthResponse, tags=["ops"])
def healthz() -> dict:
    """Used by Kubernetes liveness and readiness probes."""
    return {"status": "ok"}


@app.get("/version", response_model=VersionResponse, tags=["ops"])
def version() -> dict:
    """Returns build metadata. BUILD_SHA is injected at container build time."""
    return {"name": APP_NAME, "version": BUILD_SHA}


# --- Prometheus metrics ---
# Instrumentator exposes /metrics with default counters and histograms:
#   - http_requests_total (by method, status, handler)
#   - http_request_duration_seconds (histogram)
#   - process_*, python_gc_* metrics (from prometheus-client default)
Instrumentator().instrument(app).expose(app, endpoint="/metrics", tags=["ops"])


@app.on_event("startup")
def on_startup() -> None:
    logger.info(f"{APP_NAME} starting up, version={BUILD_SHA}")