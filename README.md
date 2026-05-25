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

## Day 2 evidence

Two environments deployed from the same chart with deliberately different values:

| Aspect       | Dev (`insider-dev` ns) | Prod (`insider-prod` ns) |
|--------------|------------------------|---------------------------|
| Release      | `app`                  | `app-prod`                |
| Replicas     | 1                      | 3                         |
| Ingress host | `insider-case.local`   | `insider-case.example.com`|
| Log level    | `DEBUG`                | `INFO`                    |
| Resources    | tight (25m / 32Mi)     | generous (100m / 96Mi)    |

A rollout/rollback cycle was exercised on the dev release. See `helm history app -n insider-dev`:

| Revision | Status     | Description       |
|----------|------------|-------------------|
| 1        | superseded | Install complete  |
| 2        | superseded | Upgrade complete  |
| 3        | superseded | Rollback to 1     |
| 4        | superseded | Upgrade complete  |
| 5        | deployed   | Rollback to 1     |

Screenshots of the cluster state are under `docs/screenshots/`.

### Ingress note

The Ingress object is provisioned correctly (`kubectl get ingress -n insider-dev` shows the address and backend bound). External `curl` access on macOS with the Docker driver requires `minikube tunnel`; this is replaced by `cloudflared` on Day 4 for the public URL.

### Resource value rationale

Values were chosen to leave headroom on a single-node minikube while keeping the QoS class predictable:
- Dev `requests: 25m/32Mi, limits: 100m/96Mi` — minimal footprint, room for multiple services on the same node.
- Prod `requests: 100m/96Mi, limits: 500m/256Mi` — more headroom for 3 replicas, still well under typical node limits.

## Roadmap

- [x]  App + Docker + repo hygiene
- [x]  Helm chart + minikube + envs
- [ ]  CI/CD + GHCR + Trivy + release
- [ ]  Observability + tunnel + docs