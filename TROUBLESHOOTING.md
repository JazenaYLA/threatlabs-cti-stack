# XTM Stack Troubleshooting Guide

## XTM Composer Errors

### 403 Forbidden: `Failed to register into OpenAEV backend`

**Symptoms:**
- `xtm-composer` logs show repeated `403` errors.
- `Failed to register` or `Failed to ping`.

**Cause:**
- The composer is using the wrong token to authenticate with OpenAEV.
- often caused by copy-pasting configuration where `${OPENCTI_ADMIN_TOKEN}` is used instead of `${OPENAEV_ADMIN_TOKEN}`.

**Solution:**
1. Check `xtm/docker-compose.yml`.
2. Ensure `OPENAEV__TOKEN` is set to `${OPENAEV_ADMIN_TOKEN}`:
   ```yaml
   xtm-composer:
     environment:
       - OPENAEV__TOKEN=${OPENAEV_ADMIN_TOKEN}
   ```
3. Redeploy the service: `docker compose up -d xtm-composer`

### 500 Internal Server Error: `Failed to fetch connector instances`

**Symptoms:**
- `xtm-composer` logs show a `500` error during startup.

**Cause:**
- **Transient issue.** OpenAEV may return a 500 error (NullPointerException) if queried too early when no connectors have registered yet.

**Solution:**
- **Ignore it.** The composer automatically retries.
- Check logs 5 seconds later; you should see `Manager registered`.

## OpenAEV Errors

### Port Conflict (9081 vs 8081)

**Symptoms:**
- OpenAEV is not accessible on expected port 9081.

**Cause:**
- Default configuration uses port **8081** (mapped to internal 8080).

**Solution:**
- Access OpenAEV at `http://<host>:8081`.
- Or update `docker-compose.yml` ports mapping if 9081 is required: `"9081:8080"`.

## General Errors

### Disk Exhaustion (Logs)

**Symptoms:**
- Disk fills up rapidly.
- `docker logs` commands hang or are slow.

**Cause:**
- Default Docker logging driver (`journald` or `json-file` without limits) can grow indefinitely.

**Solution:**
- The stack is now configured with log rotation (10MB x 3 files) for core services.
- To prune old logs/containers: `docker system prune -f`
