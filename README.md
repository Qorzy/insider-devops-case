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


## Day 3 evidence

### CI pipeline

Every PR and push to `main` runs four jobs in parallel-then-serial:

| Job | Tools | Purpose |
|-----|-------|---------|
| Lint & Test | ruff, pytest | Python code quality and unit tests |
| Helm Lint | helm | Chart validation + dev/prod template render |
| Secret Scan | gitleaks | Full-history scan with custom allowlist |
| Build, Scan & Push | docker, Trivy, GHCR | Multi-stage build, vuln scan, conditional push |

`Build, Scan & Push` only pushes to GHCR on `push` events to `main`. PR builds
are scan-only — this prevents credential leaks from forked PRs.

### Release flow

A separate `release.yml` workflow runs on `v*` tag pushes. To cut a release:

```bash
git tag -a v0.1.0 -m "first end-to-end slice"
git push origin v0.1.0
```

The workflow then:

- builds, scans (Trivy), and pushes the image to GHCR as `:0.1.0`, `:0.1`, and `:latest`
- creates a GitHub Release with notes extracted from the matching section of `CHANGELOG.md`

The image tag and the GitHub Release tag are kept in lockstep via `docker/metadata-action` with the `type=semver` pattern.

### Security findings caught by the pipeline

The first CI run failed because **Trivy flagged CVE-2025-62727** — a HIGH
severity DoS in Starlette 0.41.3 (a transitive dependency of FastAPI 0.115.4).
Fix landed in PR #4: upgrade FastAPI to 0.124.4, which bumps Starlette past
0.49 where the vulnerability is patched. **This is exactly the loop the
pipeline is built to enforce.**

Separately, `aquasecurity/trivy-action` is pinned to `v0.36.0` — the first
clean release after the March 2026 supply chain incident that compromised
75 historical tags of the same action.

### Auto-deploy on merge — choice and trade-off

**Choice:** auto-deploy is exposed as a Makefile target (`make deploy-ghcr`)
rather than wired into CI. The deploy itself is reproducible and one command;
the trigger is just kept manual for this case.

**Why not in CI:**

- The target cluster here is local minikube. GitHub-hosted runners can't
  reach a laptop's loopback Kubernetes API, so a CI step would either need
  a self-hosted runner or a publicly reachable cluster — both larger scope
  than this case study.
- Push-style deploy from CI also requires storing a long-lived kubeconfig
  as a secret, which violates the case's "no real credentials in the repo"
  goal. Track A (AWS EC2 + OIDC federation) would solve that part; Track B
  doesn't have that option.

**Why not ArgoCD / Flux:**

GitOps would be the more production-correct path: the cluster pulls instead
of CI pushing, and `main` becomes the single source of truth for cluster
state. Realistically, for a single-environment, single-service case study
it adds an ArgoCD install + an Application manifest + a separate config
repo (or directory) — all overhead with little extra teaching value on top
of what the rest of the pipeline already demonstrates.

**What this looks like locally today:**

After a PR merges to `main` and CI publishes a new `:latest` to GHCR:

```bash
make deploy-ghcr
```

That target pulls `ghcr.io/.../insider-case:latest` into minikube's Docker, runs `helm upgrade --install` on the dev release, and waits for the new pods to be ready.

**What I'd build next if this had to leave the laptop:**

1. Add a self-hosted runner inside the target cluster.
2. Replace `make deploy-ghcr` with a `deploy.yml` workflow that runs on `push` to `main` and uses that runner.
3. Eventually migrate to ArgoCD ApplicationSet across `dev` and `prod` namespaces, with `main` driving sync. The Makefile targets become the local debugging tool, not the production deploy path.

## Roadmap

- [x]  App + Docker + repo hygiene
- [x]  Helm chart + minikube + envs
- [x]  CI/CD + GHCR + Trivy + release
- [ ]  Observability + tunnel + docs