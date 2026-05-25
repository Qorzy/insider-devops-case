# Architecture Decision Records

Lightweight ADRs in [MADR-ish](https://adr.github.io/madr/) format, one decision per file.

| # | Title | Date |
|---|-------|------|
| [001](001-use-helm-for-packaging.md) | Use Helm for packaging Kubernetes manifests | 2026-05-23 |
| [002](002-base-image-python-slim.md) | Use `python:3.12-slim` as the container base image | 2026-05-22 |
| [003](003-tunnel-cloudflared-quick.md) | Use `cloudflared` quick tunnel for the public URL | 2026-05-25 |
| [004](004-pinning-third-party-actions.md) | Pin third-party GitHub Actions to a specific tag | 2026-05-25 |
| [005](005-deploy-via-makefile.md) | Keep deploy-on-merge in a Makefile, not in CI | 2026-05-25 |