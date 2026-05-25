# ADR-001 — Use Helm for packaging Kubernetes manifests

**Status:** Accepted
**Date:** 2026-05-23

## Context

The service needs to deploy to two environments (dev, prod) on a minikube cluster, with differences in replica count, resources, hostname, and log level. Manifests live alongside the application code; they need to be repeatable, parameterised, and reviewable.

## Decision

Package Kubernetes manifests as a Helm chart under `helm/insider-case/`, with `values.yaml` for defaults and `values-dev.yaml` / `values-prod.yaml` for per-environment overrides.

## Considered alternatives

- **Raw manifests + Kustomize overlays.** Lighter than Helm; no templating cognitive overhead. Rejected because environment-specific values are scalar overrides (replica count, host, log level), which Helm `--set` and value files express more concisely than Kustomize patches.
- **Plain `kubectl apply -f` with one manifest per environment.** Simplest, but duplicates 90% of the spec across environments; drift between them becomes easy.

## Consequences

**Positive.**
- `helm upgrade --install` is a single, idempotent command for both first deploy and updates.
- `helm rollback` gives time-machine semantics out of the box (used during Day 2 verification).
- `helm history` is a real audit log of what shipped when.
- Helm's own templating caught at least one mistake (`NOTES.txt` referencing a value we'd deleted) before it reached the cluster, when `helm lint` ran in CI.

**Negative.**
- Helm template syntax is its own learning curve. We mitigate this with `_helpers.tpl` for the standard labels and keep the templates short and readable.
- Releases are tracked in Secrets, which can grow over time. For this case the volume is small.