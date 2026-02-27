# Reverse Proxy Guide

This guide covers the CTI stack's transition from direct IP addressing to Caddy reverse proxy with domain-based routing, and how to configure either approach.

## Why Reverse Proxy?

The stack originally used hardcoded IPs in every `.env` file. This worked, but created a fragile configuration:

- **VLAN or IP changes** required updating every `.env` file across every stack (e.g., `http://10.0.0.50:3000`)
- **Cached registrations** (like the Forgejo runner's `.runner` file) silently kept using stale IPs
- **No TLS termination** — each service handled its own HTTPS or ran plain HTTP
- **No single ingress** — each service exposed its own port on the host

Moving to Caddy gives us:
- **One place to update** when infrastructure changes (Caddy config + DNS)
- **Domain-based routing** (`service.lab.local`) that survives IP changes
- **TLS termination** at the proxy layer
- **Simplified firewall rules** — only expose ports 80/443 on Caddy

## Two Approaches Compared

| | **Direct IP** | **Caddy Proxy** |
|---|---|---|
| `.env` example | `http://<SERVICE_IP>:3000` | `http://forgejo.lab.local` |
| IP/VLAN change | Update every `.env` + restart all | Update Caddy config only |
| TLS | Per-service or none | Centralized at Caddy |
| DNS required | No | Yes (CNAME records) |
| Complexity | Lower initial setup | Requires Caddy + DNS |
| Resilience | Fragile | Robust |

> [!IMPORTANT]
> **Both approaches work.** Direct IPs are fine for simple setups. If you plan to change VLANs, IPs, or want centralized TLS, use the reverse proxy approach.

## How It Works

```
Browser/Service → forgejo.lab.local
                    ↓ (DNS CNAME)
                  caddy.lab.local (<CADDY_IP>)
                    ↓ (reverse_proxy)
                  forgejo-container:3000 (via cti-net)
```

1. **DNS**: Each service gets a CNAME record pointing to `caddy.lab.local`
2. **Caddy**: Matches the hostname and reverse-proxies to the container on `cti-net`
3. **Docker**: Services resolve each other by container name on the shared `cti-net` network

### DNS Pattern

| Record | Type | Target |
|--------|------|--------|
| `forgejo.lab.local` | CNAME | `caddy.lab.local` |
| `opencti.lab.local` | CNAME | `caddy.lab.local` |
| `caddy.lab.local` | A | `<CADDY_IP>` |

> [!TIP]
> Only the `A` record for Caddy needs updating if Caddy's IP changes. All CNAME records stay the same.

## Setting Up Caddy

The Caddy proxy stack lives in `proxy/`:

```bash
cd proxy && docker compose up -d
```

Caddy must be on `cti-net` to reach backend services. The Caddyfile uses hostname matching to route traffic:

```
forgejo.lab.local {
    reverse_proxy forgejo-server:3000
}
```

## Migrating from Direct IPs

If you're switching an existing deployment from direct IPs to Caddy domains:

1. **Set up DNS** — create CNAME records for each service pointing to `caddy.lab.local`
2. **Update `.env` files** — replace IPs with domain names:
   ```diff
   - GITEA_INSTANCE_URL=http://<SERVICE_IP>:3000
   + GITEA_INSTANCE_URL=http://forgejo.lab.local
   ```
3. **Restart services** — `docker compose down && docker compose up -d`
4. **Check for cached state** — some services cache addresses on first boot (see Gotchas below)

> [!WARNING]
> **Don't just change `.env` and assume it works.** Some services (like the Forgejo runner) cache the server address in local files that persist across restarts. See the Gotchas section.

## Gotchas

### Cached Runner Registrations

The Forgejo runner stores the server address in `data/.runner` at registration time. Changing `GITEA_INSTANCE_URL` in `.env` does **not** update the cached address.

**Symptom**: `dial tcp <old-IP>:3000: no route to host`

**Fix**: The runner's `entrypoint.sh` now includes **URL drift detection** that automatically handles this. If you're using the old inline `command`, either:
- Delete `data/.runner` and restart, or
- Switch to the `entrypoint.sh` approach (see `forgejo-runner/README.md`)

### Services Not on `cti-net`

If a container isn't attached to `cti-net`, it can't resolve `*.lab.local` domains via Docker's internal DNS — it falls back to the host's DNS, which may resolve to a different VLAN or an unreachable IP.

**Fix**: Ensure every service that needs to reach other stacks has `networks: [cti-net]` in its compose file.

### Git Remote URLs

The git remote URL in `/opt/stacks/.git/config` and `/opt/cti-dev/.git/config` is **another place where IPs get stale**. After a VLAN change, `git push` will fail silently with `Could not connect to server`.

**Fix**: `git remote set-url origin http://forgejo.lab.local/jamz/threatlabs-cti-stack.git` (see [OPSEC](OPSEC.md#git-remote-urls))

### Internal vs External URLs

Some services need **two different URLs**:
- **Internal** (container-to-container): `http://container-name:port` via `cti-net`
- **External** (browser/API access): `http://service.lab.local` via Caddy

Example: MISP modules are reached internally as `http://misp-modules-shared:6666` but externally as `http://misp-modules.lab.local`.

> [!NOTE]
> Internal Docker DNS (`container-name:port`) is always the most reliable for container-to-container communication. Use Caddy domains for external access and cross-VLAN routing.

## Changing IPs or VLANs After Setup

With the reverse proxy approach, IP changes are localized:

1. **Caddy IP changed**: Update the single `A` record for `caddy.lab.local`
2. **Service moved to new host**: Update the Caddyfile `reverse_proxy` target
3. **VLAN restructured**: Update Caddy's network config; CNAME records stay the same

Without reverse proxy (direct IP approach), you must update every `.env` file referencing the changed IP across all stacks.

## Reference

- [Forgejo Runner README](../forgejo-runner/README.md) — runner-specific drift detection docs
- [Architecture Decisions](Architecture.md) — design rationale
- [Troubleshooting](../TROUBLESHOOTING.md) — common errors including proxy-related issues
- [Internal IPs](../internal_ips.md) — current IP/domain mapping table
