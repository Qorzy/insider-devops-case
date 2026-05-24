# Security policy

> This is a case study project. The notes below describe how I would treat security in a real production setting.

## Reporting

If you find a vulnerability, please open a private security advisory on GitHub rather than a public issue.

## Practices in this repo

- **No secrets in code** — `.env` is gitignored; only `.env.example` is committed.
- **Image scanning** — Trivy runs in CI, fails the pipeline on `CRITICAL` / `HIGH`.
- **Secret scanning** — gitleaks runs in CI on every push.
- **Non-root containers** — the runtime image uses an unprivileged user (UID 10001).
- **Pinned dependencies** — Python deps are pinned to exact versions in `requirements.txt`.

## Open items / future work

- Image signing with `cosign`
- SBOM generation with `syft`
- Renovate or Dependabot for dependency updates