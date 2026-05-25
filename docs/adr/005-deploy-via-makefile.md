# ADR-005 — Keep deploy-on-merge in a Makefile, not in CI

**Status:** Accepted
**Date:** 2026-05-25

## Context

Day 3.4 of the case asks for an auto-deploy story after a merge to `main`, with the two suggested options being:

1. `kubectl set image` from the CI pipeline.
2. GitOps via ArgoCD or Flux.

Both assume the runner can reach the cluster's Kubernetes API.

## Decision

Expose the "deploy after merge" workflow as a Makefile target (`make deploy-ghcr`) on the developer's laptop, not as a step in `ci.yml`. CI is responsible up to "image published in GHCR." Deploy is a separate, deliberate local step.

## Considered alternatives

- **`kubectl set image` from a GitHub-hosted runner.** The cluster here is a local minikube; the runner has no route to it. Wiring this up would require either a self-hosted runner inside the cluster or making the Kubernetes API publicly reachable. Both are larger scope than this case.
- **GitOps via ArgoCD.** The "more correct" pattern at scale: the cluster pulls from `main` rather than CI pushing. For a single-environment, single-service case study the operational cost (install ArgoCD, write an Application manifest, manage a separate config repo or directory) outweighs the teaching gain on top of what the rest of the pipeline already shows.
- **A `deploy.yml` workflow with a kubeconfig stored as a GitHub Secret.** Works, but stores a long-lived cluster credential in CI — directly at odds with the case's "no real credentials in the repo" rule. For Track A this could be replaced by OIDC federation to AWS; on Track B there's no equivalent native to Kubernetes.

## Consequences

**Positive.**
- The release artifact (GHCR image) is fully automated; only the cluster-touching step is manual, and it is a single `make deploy-ghcr` invocation.
- No long-lived kubeconfig in CI secrets.
- The Makefile target is also the Track B IaC story (PDF 4.3): the minikube lifecycle, image load, and deploy are all reproducible from `make help`.

**Negative.**
- Strictly speaking, "merge to main" doesn't produce a live deploy without a human running one command. For this scope it's the right trade; in production we'd move to GitOps.
- A reader doesn't see the deploy step succeed inside the GitHub Actions UI. We compensate by capturing `helm history` and `kubectl rollout status` outputs as evidence in `docs/screenshots/`.

## What changes when this graduates

The migration path is documented in the README under "What I'd build next if this had to leave the laptop": add a self-hosted runner in the target cluster, replace `make deploy-ghcr` with a workflow, eventually move to ArgoCD ApplicationSet across `dev` and `prod`.