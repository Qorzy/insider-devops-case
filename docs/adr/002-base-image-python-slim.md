# ADR-002 — Use `python:3.12-slim` as the container base image

**Status:** Accepted
**Date:** 2026-05-22

## Context

The service is a small FastAPI HTTP server. The base image choice affects three things at once: final image size, attack surface, and how easy the image is to debug when something goes wrong in production.

## Decision

Use `python:3.12-slim` as the base for both the builder and the runtime stage.

## Considered alternatives

- **`python:3.12`** (full Debian-based). Comes in around 1 GB+. Too large for what we need and includes a long list of packages we never touch.
- **`python:3.12-alpine`**. Smallest of the three. Uses `musl` libc instead of `glibc`. Some wheels (especially scientific Python and certain native extensions) don't ship for `musl` and have to be compiled from source, which slows builds and can fail unexpectedly when transitive dependencies change. For an HTTP service with `pydantic-core` (Rust) in the chain, the risk wasn't worth the size savings.
- **`gcr.io/distroless/python3`**. Smallest **and** most hardened — no shell, no package manager. Ideal for production at scale, but harder to debug (`kubectl exec -it` to poke around becomes impossible). For a project that's still demonstrating its end-to-end shape, the loss of `bash` is a real cost.

## Consequences

**Positive.**
- Final image size ~183 MB after multi-stage build.
- All pinned dependencies install from prebuilt wheels — no compilation surprises.
- A shell is available for ad-hoc debugging if the readiness probe ever lies.

**Negative.**
- Slightly larger than `alpine` (~70 MB) and noticeably larger than distroless. Trivy occasionally surfaces CVEs in the base layer that we then either patch or muffle with `ignore-unfixed: true`.
- The "graduation path" is distroless once the project is stable. The Dockerfile is structured (multi-stage, non-root user, explicit `CMD`) so that switch is small.