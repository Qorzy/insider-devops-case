# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-05-25

First release — the Day 1–3 end-to-end slice of the Insider One DevOps case study.

### Added

- **App** — FastAPI service with `/ping`, `/healthz`, `/version` endpoints
  and structured JSON logging.
- **Container** — multi-stage Dockerfile on `python:3.12-slim` with non-root
  user (UID 10001), `readOnlyRootFilesystem`, dropped capabilities, and a
  `HEALTHCHECK` against `/healthz`.
- **Helm chart** under `helm/insider-case/` with separate `values-dev.yaml`
  and `values-prod.yaml` (different replica count, log level, host, resources).
- **CI pipeline** in `.github/workflows/ci.yml`:
  - `ruff` lint and `pytest`
  - `helm lint` and template render for both dev and prod values
  - Multi-stage Docker build with GHA layer cache
  - Trivy image scan failing on `CRITICAL` / `HIGH`
  - `gitleaks` secret scan over the full git history
  - Push to `ghcr.io` on `main` only (PR builds are scan-only)
- **Release workflow** in `.github/workflows/release.yml` — on `v*` tag push,
  builds and publishes a versioned image to GHCR and creates a GitHub Release.

### Security

- `CVE-2025-62727` (HIGH, Starlette DoS via Range header merging) caught by
  Trivy on the first CI run. Resolved by upgrading FastAPI from 0.115.4 to
  0.124.4 (which bumps Starlette to >= 0.49).
- `aquasecurity/trivy-action` pinned to `v0.36.0` — the latest clean release
  after the March 2026 supply chain incident.

[Unreleased]: https://github.com/Qorzy/insider-devops-case/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Qorzy/insider-devops-case/releases/tag/v0.1.0