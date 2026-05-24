"""
Tiny HTTP service for Insider One DevOps case study.
Three endpoints: /ping (liveness signal), /healthz (probe), /version (build info).
"""
import os
import logging
import sys
import json
from fastapi import FastAPI
from pydantic import BaseModel

# --- Configuration via environment variables ---
# 12-factor: config from env, not hardcoded
BUILD_SHA = os.getenv("BUILD_SHA", "dev")
APP_NAME = os.getenv("APP_NAME", "insider-case")
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()

# --- Structured JSON logging (Day 4'te işimize yarayacak) ---
class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "timestamp": self.formatTime(record, "%Y-%m-%dT%H:%M:%S%z"),
            "level": record.levelname,
            "msg": record.getMessage(),
            "logger": record.name,
        }
        return json.dumps(payload)

handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JsonFormatter())
logging.basicConfig(level=LOG_LEVEL, handlers=[handler], force=True)
logger = logging.getLogger(APP_NAME)

# --- App ---
app = FastAPI(title=APP_NAME)


class PingResponse(BaseModel):
    message: str


class HealthResponse(BaseModel):
    status: str


class VersionResponse(BaseModel):
    name: str
    version: str


@app.get("/ping", response_model=PingResponse, tags=["core"])
def ping() -> dict:
    """Smoke test endpoint. Returns 'pong' if the process is alive."""
    return {"message": "pong"}


@app.get("/healthz", response_model=HealthResponse, tags=["ops"])
def healthz() -> dict:
    """Used by Kubernetes liveness and readiness probes."""
    return {"status": "ok"}


@app.get("/version", response_model=VersionResponse, tags=["ops"])
def version() -> dict:
    """Returns build metadata. BUILD_SHA is injected at container build time."""
    return {"name": APP_NAME, "version": BUILD_SHA}


@app.on_event("startup")
def on_startup() -> None:
    logger.info(f"{APP_NAME} starting up, version={BUILD_SHA}")