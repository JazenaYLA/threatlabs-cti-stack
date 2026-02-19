# XTM Stack Troubleshooting Guide

## XTM Composer Errors

### 403 Forbidden: `Failed to register into OpenAEV backend`

**Symptoms:**
- `xtm-composer` logs show repeated `403` errors.
- `Failed to register` or `Failed to ping`.

**Cause:**
- The composer is using the wrong token to authenticate with OpenAEV.
- Often caused by copy-pasting configuration where `${OPENCTI_ADMIN_TOKEN}` is used instead of `${OPENAEV_ADMIN_TOKEN}`.

**Solution:**
1. Check `xtm/docker-compose.yml`.
2. Ensure `OPENAEV__TOKEN` is set to `${OPENAEV_ADMIN_TOKEN}`:
   ```yaml
   xtm-composer:
     environment:
       - OPENAEV__TOKEN=${OPENAEV_ADMIN_TOKEN}
   ```
3. Redeploy the service: `docker compose up -d xtm-composer`

### OpenCTI Schema Conflict (ElasticSearch 8)

**Symptoms:**
- `opencti` container stays in a loop or fails to initialize.
- Logs show `[ERROR] Connection to the search engine failed` or index mapping conflicts.

**Cause:**
- Existing indices in ES8 from a previous partial or failed installation preventing clean schema generation.

**Solution (Deep Reset):**
1. Stop the stack: `docker compose down`.
2. Clean ES8 data: `sudo rm -rf /opt/stacks/infra/vol/es8/data/*`.
3. Restart infra first, then XTM:
   ```bash
   cd /opt/stacks/infra && docker compose up -d
   cd /opt/stacks/xtm && docker compose up -d
   ```

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

# Shuffle Stack Errors

## Tenzir Load_TCP Error

**Symptoms:**
- `shuffle-orborus` logs show errors when loading workflows.
- `tenzir-node` crashes or restarts repeatedly.
- Error related to `load_tcp` operator.

**Cause:**
- Incompatibility between Tenzir version and Shuffle's generated queries.
- Incorrect command launch for Tenzir v4+.

**Solution:**
1. Use `tenzir/tenzir:v4.18.0` image.
2. Set command in `docker-compose.yml`: `command: /opt/tenzir/bin/tenzir-node --endpoint=0.0.0.0:5160`.
3. Set entrypoint to empty array: `entrypoint: []`.
4. Ensure volume permissions are correct: `chown -R 1000:1000 ./vol/tenzir-lib`.

## OpenSearch Mapping Error: `No mapping found for [updated_at]`

**Symptoms:**
- `shuffle-backend` logs show `search_phase_execution_exception`.
- Error message: `No mapping found for [updated_at] in order to sort`.
- Notifications or other sorted queries fail.

**Cause:**
- The `notifications` index was created without the correct schema mapping for the `updated_at` field (likely treated as text/keyword instead of date).

**Solution:**
1. Manually apply the correct mapping to the index:
   ```bash
   curl -X PUT "http://localhost:9200/notifications-000001/_mapping" \
     -u admin:<password> \
     -H 'Content-Type: application/json' \
     -d '{"properties": {"updated_at": {"type": "date"}}}'
   ```

# MISP Stack Errors

## Worker Fatal Error: `blpop() on null`

**Symptoms:**
- `misp-workers-errors.log` shows `Error: Call to a member function blpop() on null`.
- Workers exit with FATAL state in Supervisord.

**Cause:**
- `SimpleBackgroundJobs` plugin is not initializing the Redis connection correctly.
- Usually due to the `enabled` setting evaluating to `false` in `BackgroundJobsTool`.

**Solution:**
1. Verify `SimpleBackgroundJobs` is enabled in `app/Config/config.php`.
2. Ensure environment variables in `docker-compose.yml` are not overriding critical settings with empty values.

## Healthcheck Access Denied (Internal Database Only)

**Symptoms:**
- `misp-core` container remains "Starting" or "Unhealthy" even when the UI works.
- Logs show `Access denied for user 'misp'@'172.x.x.x'` during healthcheck commands.

**Cause:**
- The internal healthcheck script (inside `misp-core`) uses `MYSQL_USER` and `MYSQL_PASSWORD` from the `.env` file to verify DB connectivity. 
- If credentials in the application's `.env` (misp) don't match the database's `.env` (infra), the healthcheck will fail.

**Solution:**
- Ensure `MYSQL_USER` and `MYSQL_PASSWORD` in `/opt/stacks/misp/.env` matches exactly the credentials used in `/opt/stacks/infra/.env`.
- Restart the container: `docker compose up -d --force-recreate misp-core`.

## Shuffle Connectivity & Version Issues

### OpenSearch Startup Failure: `AccessDeniedException`

**Symptoms:**
- `shuffle-opensearch` container restarts repeatedly.
- Logs show `java.nio.file.AccessDeniedException: /usr/share/opensearch/data/nodes`.
- `shuffle-backend` fails to connect to OpenSearch.

**Cause:**
- Incorrect ownership of the mounted data directory (`vol/opensearch-data`).
- OpenSearch runs as UID 1000, but the directory might be owned by root due to Docker creation, preventing write access.

**Solution:**
1. Stop the stack: `docker compose down`.
2. Fix ownership: `chown -R 1000:1000 vol/opensearch-data`.
3. (Optional) Force permissions: `chmod -R 777 vol/opensearch-data`.
4. Restart the stack: `docker compose up -d`.

### OpenSearch Connection Refused (HTTP vs HTTPS)

**Symptoms:**
- `shuffle-backend` logs show `dial tcp 172.x.x.x:9200: connect: connection refused`.
- Connection fails even when OpenSearch is running.

**Cause:**
- Protocol mismatch: Shuffle might default to `https://` but OpenSearch listens on `http://`.
- `SHUFFLE_OPENSEARCH_URL` missing or incorrect.

**Solution:**
1. Update `.env`:
   ```bash
   SHUFFLE_OPENSEARCH_URL=http://shuffle-opensearch:9200
   ```
2. Recreate `shuffle-backend`: `docker compose up -d --force-recreate shuffle-backend`.

### Orborus Docker Client Error: `client version 1.40 is too old`

**Symptoms:**
- `shuffle-orborus` logs: `Error response from daemon: client version 1.40 is too old. Minimum supported API version is 1.44`.

**Cause:**
- Shuffle v2.2.0 uses a client library that tries to negotiate an API version older than what the Docker Daemon supports.
- `DOCKER_API_VERSION` env var is missing or set to an old value (e.g., 1.40).

**Solution:**
1. Update `.env` and `.env.example`:
   ```bash
   DOCKER_API_VERSION=1.44
   ```
2. Restart: `docker compose up -d shuffle-orborus`.

# TheHive Stack Errors

## Cassandra Permission Denied: `AccessDeniedException`

**Symptoms:**
- `thehive-cassandra` container restarts repeatedly.
- Logs show `java.nio.file.AccessDeniedException: /var/lib/cassandra/data`.

**Cause:**
- Cassandra runs as UID `999`. If permissions on `thehive/vol/cassandra/data` are incorrect (e.g., owned by root), it cannot start.

**Solution:**
1. Reset ownership recursively:
   ```bash
   sudo chown -R 999:999 /opt/stacks/thehive/vol/cassandra/data
   ```
2. Restart the stack.

# Global Infrastructure Reset

## Deep Volume Wipe for Credential Sync

If you significantly change database passwords or encounter corrupted search clusters:

1. **Stop all stacks.**
2. **Postgres Reset**: `sudo rm -rf /opt/stacks/infra/vol/postgres/data/*` (Forces re-initialization of all DBs/Users via `init-dbs.sh`).
3. **Search Reset**: 
   - ES7: `sudo rm -rf /opt/stacks/infra/vol/es7/data/*`
   - ES8: `sudo rm -rf /opt/stacks/infra/vol/es8/data/*`
4. **Valkey Reset**: `sudo rm -rf /opt/stacks/infra/vol/valkey/data/*`
5. **Restart Infra**, then wait for healthy state before starting dependent stacks.
