# RUNBOOK

Short, action-oriented operating guide for `insider-case`. Read top to bottom in an incident; jump to the section you need otherwise.

## At a glance

| Thing | Where |
|-------|-------|
| Source repo | `github.com/Qorzy/insider-devops-case` |
| Container image | `ghcr.io/qorzy/insider-devops-case/insider-case` |
| Cluster | `minikube` (single node, Docker driver) |
| Dev namespace / release | `insider-dev` / `app` |
| Prod-like namespace / release | `insider-prod` / `app-prod` |
| Observability | `monitoring` namespace (Prometheus, Grafana, Alertmanager) |
| Public URL | cloudflared quick tunnel (printed when started) |

## Health quick-check

```bash
make status                            # pods + helm history at a glance
curl http://insider-case.local/ping    # should return {"message":"pong"}
curl http://insider-case.local/healthz # should return {"status":"ok"}
```

If `make status` shows pods not `Running 1/1`, jump to **Pod won't start**. If the `curl`s hang, jump to **Tunnel issues**.

## Pod won't start

```bash
kubectl get pods -n insider-dev
kubectl describe pod -n insider-dev -l app.kubernetes.io/name=insider-case
kubectl logs    -n insider-dev -l app.kubernetes.io/name=insider-case --tail=100
```

Common causes:
- `ImagePullBackOff` — image not present in minikube. Rebuild into minikube's Docker:
  ```bash
  eval $(minikube docker-env)
  make image-load
  ```
- `CrashLoopBackOff` — check logs for a traceback. If `readOnlyRootFilesystem` is the problem, the chart already mounts a writable `/tmp` via emptyDir if needed; otherwise the app expects only env-driven config.

## Look at logs

```bash
# Live tail across pods in the dev release
kubectl logs -n insider-dev -l app.kubernetes.io/name=insider-case -f --tail=50

# Filter by request_id (logs are structured JSON)
kubectl logs -n insider-dev -l app.kubernetes.io/name=insider-case --tail=500 \
  | grep '"request_id":"<id-here>"'
```

Every request gets an `x-request-id` header. Pass it in to correlate client and server:
```bash
curl -i -H "X-Request-ID: my-trace" http://insider-case.local/ping
```

## Restart pods

Without a config or image change (force a refresh anyway):
```bash
kubectl rollout restart deployment/app-insider-case -n insider-dev
kubectl rollout status  deployment/app-insider-case -n insider-dev
```

After a code change, rebuild and redeploy in one go:
```bash
eval $(minikube docker-env)
make image-load                              # builds and side-loads
make deploy-dev                              # helm upgrade --install
```

## Roll back a bad release

```bash
helm history app -n insider-dev              # find the previous good REVISION
helm rollback app <REVISION> -n insider-dev --wait
kubectl rollout status deployment/app-insider-case -n insider-dev
```

Or use the Makefile shortcut (rolls back to the previous revision):
```bash
make rollback-dev
```

## Deploy a specific GHCR image tag

```bash
# Pull a versioned image into minikube and deploy it to dev
eval $(minikube docker-env)
docker pull ghcr.io/qorzy/insider-devops-case/insider-case:v0.1.0

helm upgrade app helm/insider-case \
  -f helm/insider-case/values-dev.yaml \
  --set image.repository=ghcr.io/qorzy/insider-devops-case/insider-case \
  --set image.tag=v0.1.0 \
  --namespace insider-dev --wait
```

## Tunnel issues (public URL down)

The public URL relies on two foreground processes on the laptop:
- `minikube tunnel` (routes traffic from the laptop to the cluster's port 80/443)
- `cloudflared tunnel --url http://insider-case.local --http-host-header insider-case.local`

If the URL stops responding:

```bash
ps aux | grep -E "minikube tunnel|cloudflared" | grep -v grep

# Restart minikube tunnel (asks for sudo)
minikube tunnel
# (in another terminal) restart cloudflared
cloudflared tunnel --url http://insider-case.local --http-host-header insider-case.local
```

A new cloudflared session prints a new `*.trycloudflare.com` URL. Use that one.

## Rotate a secret

This project does not commit real secrets and uses `GITHUB_TOKEN` for GHCR auth (no PATs). If a secret ever needs to be rotated:

1. Revoke the leaked credential at its provider (GitHub, AWS, etc.).
2. Run `gitleaks detect --redact` locally to confirm scope of exposure.
3. If the secret reached a public commit, rewrite history with `git filter-repo` and force-push (coordinate with anyone with clones — this is destructive). Then file a `SECURITY` note in the README.
4. Generate the replacement secret and put it in **GitHub Repo → Settings → Secrets and variables → Actions**. Never paste it into a workflow file or commit.

## Alerts firing

| Alert | Likely cause | First step |
|-------|--------------|------------|
| `InsiderCaseHighErrorRate` | New deploy regressed, downstream dependency down, or a bad config map | `kubectl logs --tail=200`, then `helm history` to see the most recent rollout |
| `InsiderCasePodRestarting` | App crashes on startup or liveness probe failing repeatedly | `kubectl describe pod` — look at `Last State: Terminated` and exit code |

Silence noisy alerts in Grafana → **Alerting → Silences** while investigating.

## Tear it all down (clean slate)

```bash
helm uninstall app -n insider-dev || true
helm uninstall app-prod -n insider-prod || true
helm uninstall monitoring -n monitoring || true
make cluster-destroy                          # deletes the entire minikube cluster
```

To bring it back up from scratch:
```bash
make cluster-up
make image-load
make deploy-dev
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace
```