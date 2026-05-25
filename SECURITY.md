# Security policy

> This is a case study project. The notes below describe how I treat security in this codebase and how I would scale the practices in a real production setting.

## Reporting

If you find a vulnerability, please open a private security advisory on GitHub rather than a public issue.

## Practices in this repo

### Secrets

- `.env` is gitignored; only `.env.example` (placeholder values) is committed.
- `.gitleaks.toml` extends the default ruleset and runs on **every PR and push** via the `secret-scan` job. The full git history is scanned, not just the latest commit.
- CI authenticates to GHCR with the workflow's built-in `GITHUB_TOKEN`. No long-lived Personal Access Tokens live in the repo or in CI secrets.

### Image hardening

- The runtime image runs as a non-root user (UID 10001).
- `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false`, and `capabilities.drop: [ALL]` are enforced at the container level via Helm `securityContext`.
- Multi-stage Docker build keeps build-time tools out of the final image.

### Vulnerability scanning

- Trivy scans every image in CI with `severity: CRITICAL,HIGH` and `exit-code: 1`. CRITICAL or HIGH findings fail the pipeline.
- `ignore-unfixed: true` so we don't fail on CVEs without an upstream fix yet — we re-evaluate when a fix lands.

### Supply chain

- All third-party GitHub Actions are pinned to a specific tag (e.g. `aquasecurity/trivy-action@v0.36.0`).
- The Trivy action is intentionally pinned past the March 2026 supply chain incident that compromised 75 historical tags; v0.36.0 is the first clean release after that incident.

### Dependencies

- Python dependencies are pinned to exact versions in `requirements.txt`.
- `requirements-dev.txt` keeps test and lint tooling out of the runtime image.

### Network

- Cluster-internal traffic uses a `ClusterIP` Service; external traffic enters through the nginx Ingress controller.
- The public URL terminates TLS at Cloudflare's edge (quick tunnel).

## Vulnerabilities found and fixed during the build

| CVE | Severity | Component | Resolution |
|-----|----------|-----------|------------|
| `CVE-2025-62727` | HIGH | Starlette 0.41.3 (transitive via FastAPI 0.115.4) | Upgraded FastAPI to 0.124.4, which bumps Starlette past 0.49 |

Trivy caught this on the very first PR. The pipeline did its job — the fix landed before the image reached GHCR.

## Open items / next steps

If this project graduated to production, the next security investments would be:

- **Image signing** with `cosign` and a verifying admission controller (e.g. Kyverno) on the cluster side.
- **SBOM generation** with `syft`, attached to releases.
- **Renovate or Dependabot** for automated dependency PRs.
- **Per-environment kubeconfigs** scoped to a deploy-only ServiceAccount, instead of cluster-admin context for `helm upgrade`.
- **Egress NetworkPolicy** to restrict outbound traffic from app pods to only what they actually need.