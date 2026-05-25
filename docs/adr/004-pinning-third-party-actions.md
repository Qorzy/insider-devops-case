# ADR-004 — Pin third-party GitHub Actions to a specific tag

**Status:** Accepted
**Date:** 2026-05-25

## Context

The CI workflow uses several third-party GitHub Actions (`docker/build-push-action`, `aquasecurity/trivy-action`, `gitleaks/gitleaks-action`, etc.). Each `uses:` is essentially "run arbitrary code from this repo on every CI run." Choosing how to pin matters.

In March 2026 the `aquasecurity/trivy-action` repository was compromised: an attacker force-pushed malicious code to 75 historical tags. Anyone using `@vX.Y.Z` for any of those tags suddenly started running the attacker's payload on the next CI run. Only `v0.35.0` was untouched at the time; `v0.36.0` is the first clean release published after the incident.

## Decision

Pin every third-party action to a **named tag** (not a moving ref like `@main` or `@master`). Specifically:

- `aquasecurity/trivy-action@v0.36.0` (post-incident clean release)
- `docker/build-push-action@v6`, `docker/login-action@v3`, etc. (major version tags from Docker's official set)
- `actions/*` (GitHub's own actions) pinned to major versions like `@v4`

For non-`actions/*` actions where we want maximum paranoia, we accept upgrading to a **full commit SHA pin** when the next supply chain incident makes that the obvious move.

## Considered alternatives

- **Pin everything to a commit SHA.** Most secure; resilient even to tag tampering. Rejected for now because it makes upgrades noisy (every patch is a Dependabot PR with a hash) and because for actions from well-known publishers (Docker, GitHub) the marginal risk is small.
- **Use floating refs like `@main`.** Lowest friction, highest risk. Rejected outright.

## Consequences

**Positive.**
- The repo's exposure to a future supply chain compromise is bounded by the cadence at which we choose to upgrade tags.
- A reader can reproduce CI behavior by reading the workflow alone; nothing depends on what `main` looks like today.

**Negative.**
- We won't get patch-level fixes automatically. Mitigation: review action releases periodically.
- When a supply chain incident is announced (as with Trivy), we need to manually verify we're on a clean tag and bump if not. The bump itself is one line.