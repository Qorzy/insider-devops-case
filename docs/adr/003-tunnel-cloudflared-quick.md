# ADR-003 — Use `cloudflared` quick tunnel for the public URL

**Status:** Accepted
**Date:** 2026-05-25

## Context

Track B of the case study runs Kubernetes locally on a laptop and exposes the service to the public internet through a tunnel. The case calls out `ngrok` and `cloudflared` as the obvious candidates.

## Decision

Use `cloudflared tunnel --url http://insider-case.local --http-host-header insider-case.local`. No account, no DNS configuration; the tunnel prints a random `*.trycloudflare.com` URL per session.

## Considered alternatives

- **ngrok free tier.** Familiar and fast to spin up. Free plan has stricter session limits and a more aggressive idle disconnect, which becomes a problem if the laptop's screen sleeps mid-evaluation. Also rate-limits free tier connections more visibly.
- **`cloudflared` named tunnel** (account + DNS record). Stable URL across restarts, custom domain, full TLS. The right answer if the project had to live for weeks. Overkill for a one-time evaluation and adds account/DNS coupling that the case explicitly avoids.
- **`kubectl port-forward` over SSH from a public host.** Possible but introduces another moving part and a public jump box. Not in scope.

## Consequences

**Positive.**
- One command, no account needed.
- TLS is terminated at Cloudflare's edge — the service ships with HTTPS even though the cluster speaks plain HTTP internally.
- The `--http-host-header` flag rewrites the `Host` so the nginx Ingress (which routes by host) accepts the traffic without us having to make the chart accept arbitrary hosts.

**Negative.**
- The URL changes every time the tunnel restarts. We include the current URL in the submission and in the README's "current public URL" note; the demo isn't valid if the laptop sleeps.
- No persistent observability for the tunnel itself. A named tunnel would expose metrics; the quick tunnel doesn't.
- Bound to the laptop. The upgrade path is the named tunnel + DNS, with the chart untouched.