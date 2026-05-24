# insider-devops-case

> Insider One DevOps Internship Case Study — a small, end-to-end production slice.

A tiny HTTP service packaged with Docker, deployed to minikube via Helm, automated through GitHub Actions, made observable with Prometheus/Grafana, and exposed to the internet through a public tunnel.

**Track:** B — local minikube + tunnel
**Status:** In progress

## Quick start (local)

```bash
# 1. Install Python deps (for tests)
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt

# 2. Run tests
pytest -v

# 3. Run with Docker
docker compose up -d --build
curl http://localhost:8080/ping
# {"message":"pong"}
```

## Endpoints

| Path           | Purpose                                  |
|----------------|------------------------------------------|
| `GET /ping`    | Smoke test, returns `pong`               |
| `GET /healthz` | Liveness/readiness probe target          |
| `GET /version` | Build SHA + app name                     |
| `GET /docs`    | Auto-generated OpenAPI/Swagger UI        |

## Architecture

> Diagram will come.

```
[client] → [tunnel] → [minikube ingress] → [Service] → [Pod: insider-case]
                                                          ↓
                                                  [Prometheus + Grafana]
```

## Repository layout

```
.
├── app/                  # FastAPI service
├── tests/                # pytest unit tests
├── helm/                 # Helm chart (Day 2)
├── .github/workflows/    # CI/CD pipelines (Day 3)
├── Dockerfile            # Multi-stage, non-root, slim base
├── docker-compose.yaml   # Local dev convenience
└── docs/                 # ADRs, RUNBOOK, SECURITY (Day 4)
```

## Configuration

All config is environment-driven (12-factor). See `.env.example`.

| Variable    | Default          | Purpose                                |
|-------------|------------------|----------------------------------------|
| `APP_NAME`  | `insider-case`   | Used in logs and `/version`            |
| `BUILD_SHA` | `dev`            | Injected by CI at build time           |
| `LOG_LEVEL` | `INFO`           | `DEBUG`, `INFO`, `WARNING`, `ERROR`    |

## Decisions

Key choices are documented as ADRs under `docs/adr/`. Highlights so far:

- **Python + FastAPI** — fast iteration, auto-OpenAPI, mature Prometheus instrumentation.
- **`python:3.12-slim` base image** — middle ground between Alpine and distroless (hard to debug).
- **Multi-stage Docker build with non-root user** — smaller image, smaller attack surface.

## AI assistance

This project was built with the help of AI (Claude, Gemini). Architecture, tool choices, and trade-offs were discussed and decided by me; the assistant accelerated boilerplate and surfaced production concerns. Each major decision is captured in an ADR.

## Roadmap

- [x]  App + Docker + repo hygiene
- [ ]  Helm chart + minikube + envs
- [ ]  CI/CD + GHCR + Trivy + release
- [ ]  Observability + tunnel + docs