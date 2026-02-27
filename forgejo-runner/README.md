# Forgejo Action Runner

Deployment runner for the CTI Stack ecosystem.

## Quick Start

1. Copy `.env.example` to `.env` and fill in your values
2. Run `docker compose up -d`
3. The runner will auto-register and start listening for jobs

## How It Works

### Entrypoint Script (`entrypoint.sh`)

The runner uses a custom entrypoint that handles three things on every container start:

1. **Node.js fix** — installs Node.js (not included in the base image)
2. **URL drift detection** — compares the cached Forgejo address in `data/.runner` against `GITEA_INSTANCE_URL`. If they differ (e.g. after a VLAN move or IP change), it deletes the stale registration and re-registers automatically
3. **Auto-registration** — if no `data/.runner` file exists, registers the runner using env vars
4. **Daemon start** — starts the runner daemon

### Network

The runner connects to `cti-net` (external Docker network) to reach Forgejo via its Caddy proxy domain (`forgejo.lab.local`). Always use Caddy domains in `GITEA_INSTANCE_URL`, never raw IPs.

## Changing IPs or VLANs

If the Forgejo server moves to a different IP, VLAN, or domain:

1. Update `GITEA_INSTANCE_URL` in `.env`
2. Restart: `docker compose down && docker compose up -d`
3. The entrypoint detects the URL mismatch and re-registers — **no manual intervention needed**

You'll see this in the logs:
```
================================================================
  URL DRIFT DETECTED
  Cached : http://old-address
  Current: http://new-address
  → Removing stale registration, will re-register...
================================================================
```

## Environment Separation

The runner supports two distinct environments on the same host:

- **Production** (`/opt/stacks`): Persistent stack managed via the `main` branch
- **Development** (`/opt/cti-dev`): Experimental stack managed via the `auto-swapper` branch

Both directories are mounted as volumes inside the runner container.

### Deployment Logic (`deploy.yml`)

- **Pushes to `auto-swapper`**: Auto-syncs to `/opt/cti-dev` and restarts dev containers
- **Pushes to `main`**: **DISABLED** for production safety — requires manual `workflow_dispatch`

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `dial tcp <IP>:3000: no route to host` | Stale `.runner` cached address | Update `.env` and restart — drift detection handles re-registration |
| `registration file not found` | Missing `data/.runner` | Ensure `GITEA_INSTANCE_URL` and `GITEA_RUNNER_TOKEN` are set in `.env`, then restart |
| `fail to invoke Declare` | Forgejo unreachable from container | Verify runner is on `cti-net` and Caddy is proxying to Forgejo |
| Runner registers but can't reach Forgejo | DNS resolution failure inside container | Check that `cti-net` is attached and `forgejo.lab.local` resolves correctly |

### Manual Re-registration

If you need to force a fresh registration:

```bash
rm data/.runner
docker compose down && docker compose up -d
```

### Check Runner Status

```bash
# View recent logs
docker logs forgejo_runner --tail 30

# Inspect cached registration
cat data/.runner
```
