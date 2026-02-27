# OPSEC — Documentation & Commit Hygiene

This repo mirrors to **public GitHub** via Forgejo. All committed content is publicly visible. Follow these rules to avoid leaking private infrastructure details.

## Rules

1. **Never commit real IPs, VLANs, or subnet ranges** — use placeholders like `<SERVICE_IP>`, `<CADDY_IP>`, `10.0.0.x`
2. **Never commit real tokens, passwords, or API keys** — use `ChangeMe_*` placeholders in `.env.example` files
3. **Never commit hostnames that reveal internal DNS structure** — `*.lab.local` is fine (generic); actual FQDNs tied to your infra are not
4. **Use `.gitignore` for private notes** — files like `internal_ips.md` are gitignored and safe for real values

## What's Private (Gitignored)

These files contain real infrastructure details and are **excluded from git**:

| File | Purpose |
|------|---------|
| `internal_ips.md` | Real IP/VLAN/port mapping table |
| `.env` (all stacks) | Real secrets, tokens, and passwords |
| `docs/LXC-Integration-Guide.md` | Internal LXC provisioning details |
| `**/vol/` | Persistent data volumes |
| `*_private.md` | Any file matching this pattern (see below) |

## Writing Private Notes

If you need to document something with real infrastructure details:

1. **Name the file with a `_private` suffix** — e.g., `network_private.md`, `migration_notes_private.md`
2. These are automatically gitignored via the `*_private.md` pattern
3. Reference private notes from public docs using generic language:
   ```markdown
   > See `internal_ips.md` for the actual IP/domain mapping table (not committed).
   ```

## Pre-Commit Checklist

Before pushing to Forgejo:

- [ ] `grep -rn '192\.168\.' docs/ README.md TROUBLESHOOTING.md` — should return nothing
- [ ] `grep -rn 'password\|token\|secret' docs/` — no real credentials
- [ ] New `.md` files with real IPs use `_private.md` suffix or are in `.gitignore`

## Git Remote URLs

Git remote URLs are **another place where IPs get stale**. After an IP/VLAN change, git push will fail with `Could not connect to server`.

**Check**: `git remote -v` in both `/opt/stacks` and `/opt/cti-dev`

**Fix**:
```bash
# Production
cd /opt/stacks
git remote set-url origin http://forgejo.lab.local/jamz/threatlabs-cti-stack.git

# Development
cd /opt/cti-dev
git remote set-url origin http://forgejo.lab.local/jamz/threatlabs-cti-stack.git
```

> [!NOTE]
> After changing the remote URL, you may need to re-authenticate since credentials are cached per-hostname. Use `git config --global credential.helper store` and push once to re-cache.

## For AI Assistants

When generating or updating documentation:

- Always use `<PLACEHOLDER>` syntax for IPs, tokens, and credentials
- Check existing `.gitignore` before creating files with sensitive content
- Reference `internal_ips.md` for real values but never copy them into tracked files
- After edits, scan for leaked IPs: `grep -rn '192\.168\.' docs/ *.md`
