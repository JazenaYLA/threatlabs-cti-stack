# Troubleshooting Guide

This guide addresses common issues encountered when deploying the ThreatLabs CTI stack on virtualization/Dockge.

## Quick Checks Sequence

If something isn't working, check these in order:

1. **Network Check**: Is `cti-net` active?

    ```bash
    docker network ls | grep cti-net
    ```

    *Fix*: Run `./setup.sh` or `docker network create cti-net`.

2. **Persistence Permissions**:
    * **ElasticSearch**: Requires UID `1000`.
    * **PostgreSQL**: Alpine-based version 17 requires UID `70` (not `999`).
    * **Cassandra**: Requires UID `999`.
    * *Fix*: `sudo chown -R <UID>:<UID> vol/<service-data>`.

3. **Infrastructure Health**: Are ElasticSearch nodes ready?

    ```bash
    curl http://localhost:9200/_cluster/health?pretty  # ES7
    curl http://localhost:9201/_cluster/health?pretty  # ES8
    ```

    *Fix*: Restart `infra` stack. Check `vm.max_map_count` on host.

3. **Permissions**: Are volumes owning the right user?
    *Description*: Services crash with "Permission denied".
    *Fix*: Run `./setup.sh` to apply recursive ownership to `./vol` directories.

## Common Error Messages

### `service "..." refers to undefined network cti-net`

**Cause**: The stack cannot see the shared network, or it's named incorrectly in `docker-compose.yml`.
**Solution**:

1. Ensure the `infra` stack is started (it creates `cti-net`).
2. Verify `docker-compose.yml` has:

   ```yaml
   networks:
     cti-net:
       external: true
       name: cti-net
   ```

### ElasticSearch exits with `max virtual memory areas vm.max_map_count [...] is too low`

**Cause**: Host kernel limit is too low for ES.
**Solution**:

```bash
sudo sysctl -w vm.max_map_count=262144
# To make permanent:
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

### Dockge cannot find `xtm` or `thehive` stacks

**Cause**: Dockge may not index subdirectories recursively.
**Solution**: Symlink the compose files to the root stacks directory.

```bash
cd /opt/stacks
ln -s /path/to/repo/xtm/docker-compose.yml xtm
ln -s /path/to/repo/thehive/docker-compose.yml thehive
```

### MISP feed fetch is stuck / Queue full

**Cause**: Initial fetch of all feeds can overload workers.
**Solution**:

1. Increase workers in **Administration > Server Settings > Workers**.
2. Restart workers: `sudo supervisorctl restart all` (inside container).

### Healthcheck Access Denied (Internal DB)

**Cause**: The `misp-core` healthcheck uses `.env` credentials. If they mismatch the `infra` DB settings, the container stays "Unhealthy".
**Fix**: Ensure `MYSQL_USER`/`PASS` in `misp/.env` matches `infra/.env`.

### Database Connection Failures (Shared Infra)

**Issue**: Services like `n8n`, `xtm` (OpenAEV), or `flowintel` fail to start with database auth errors.

**Cause**: Mismatch between the credentials created by `infra` and what is configured in your `.env`.

**Check**:

1. Verify `infra` is running and healthy (`infra-postgres`).
2. Check the logs of the failing service (`docker logs n8n-cti`). If you see "password authentication failed":
    * Compare your local `.env` (e.g., `n8n/.env`) against the defaults in `infra/vol/postgres-init/init-dbs.sh` or `infra/.env` variables.
    * **Fix**: Update your `.env` to match the expected credentials (e.g., ensure `N8N_DB_PASSWORD` in `n8n/.env` matches `infra/.env`).

### "Factory Reset" Needed

**Issue**: The stack is in an undefined state, volumes are corrupted, or you just want to start over.

**Fix**: Use the provided nuking script.

1. Run `./reset.sh`.
2. Type `NUKE` to confirm.
3. Run `./setup.sh` to recreate the directory structure and permissions.

## Specific Stack Issues

### "Secret Key" Errors (TheHive)

**Issue**: Service logs show errors about `play.http.secret.key` or fails to start with configuration errors.

**Cause**: The application secret key is missing or invalid. We now use environment variables (`THEHIVE_SECRET`) instead of hardcoding them in `application.conf`.

**Fix**:

1. Check `thehive/.env` for `THEHIVE_SECRET`.
2. Ensure `docker-compose.yml` passes this variable to the container.

### AIL Project

* **Issue**: Redis continuously restarts/crashes in independent instances.
* **Cause**: ZFS file system incompatibility with Redis persistence.
* **Fix**: Disable `use_direct_io_for_flush_and_compaction` in `redis.conf`. See `ail-project/README.md` for the full fix.

### TheHive

* **Issue**: TheHive cannot connect to ElasticSearch.
* **Check**: TheHive 4 requires **ElasticSearch 7**.
* **Fix**: Ensure `es7-cti` service in `infra` is healthy and env `ES_HOSTS` points to `es7-cti:9200`.

* **Issue**: TheHive crash-loops with `NoSuchFileException: /opt/thp/thehive/data`.
* **Cause**: Missing volume mount for local file storage.
* **Fix**: Ensure `docker-compose.yml` mounts the data directory:
    ```yaml
    volumes:
      - ./vol/thehive/application.conf:/etc/thehive/application.conf:ro
      - ./vol/thehive/data:/opt/thp/thehive/data
    ```
    Then create the directory: `sudo mkdir -p thehive/vol/thehive/data && sudo chown -R 1000:1000 thehive/vol`

### DFIR-IRIS

* **Issue**: Cannot find the administrator password.
* **Cause**: The admin password is randomly generated and printed in the `iris-app` logs only on the very first boot.
* **Fix**: Search the logs:
    ```bash
    sudo docker logs iris-app 2>&1 | grep "create_safe_admin"
    ```
    To set a specific password, configure `IRIS_ADM_PASSWORD` in `dfir-iris/.env` **before** first boot.

* **Issue**: IRIS shows certificate errors or nginx won't start.
* **Cause**: Self-signed certificates are missing from `certificates/web_certificates/`.
* **Fix**: Run `./setup.sh` to auto-generate certificates, or manually:
    ```bash
    cd dfir-iris
    mkdir -p certificates/{rootCA,web_certificates,ldap}
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
      -keyout certificates/web_certificates/iris_dev_key.pem \
      -out certificates/web_certificates/iris_dev_cert.pem \
      -subj "/CN=iris.local"
    ```

### FlowIntel
 
* **Issue**: Initial admin credentials not working or want to change them.
* **Cause**: FlowIntel by default hardcodes `admin@admin.admin` / `admin` in `init_db.py`.
* **Fix**:
    1. Update `flowintel/.env` with desired `INIT_ADMIN_EMAIL` and `INIT_ADMIN_PASSWORD`.
    2. Reset the database to force re-initialization (WARNING: DATA LOSS):

    ```bash
    # Stop Container
    docker compose -f flowintel/docker-compose.yml down
    
    # Drop and Recreate DB (in infra-postgres)
    docker exec infra-postgres psql -U postgres -d postgres -c "DROP DATABASE IF EXISTS flowintel;"
    docker exec infra-postgres psql -U postgres -d postgres -c "CREATE DATABASE flowintel;"
    docker exec infra-postgres psql -U postgres -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE flowintel TO flowintel;"
    docker exec infra-postgres psql -U postgres -d flowintel -c "GRANT ALL ON SCHEMA public TO flowintel;"
    
    # Restart to trigger entrypoint patch and init
    docker compose -f flowintel/docker-compose.yml up -d
    ```
    
    *Note: The `entrypoint.sh` includes a python script that patches `app/utils/init_db.py` at runtime to enforce your environment variables.*

### OpenCTI
 
* **Issue**: Connectors not showing up or "rabbitmq" connection refused.
* **Check**: Is the shared RabbitMQ in `xtm` healthy?
* **Fix**: Check `xtm` logs: `docker compose logs -f rabbitmq`.

* **Issue**: `VALIDATION_ERROR` — `"input.id" is null` in OpenCTI logs (`RegisterConnector` operation).
* **Cause**: One or more connector services defined in `docker-compose.yml` have a blank `CONNECTOR_*_ID` env var (commented out in `.env` but the service is still active).
* **Fix**: Either:
    1. Uncomment the connector ID in `.env` and generate a valid UUIDv4, or
    2. Comment out the corresponding service definition in `docker-compose.yml`.

### OpenAEV

* **Issue**: OpenAEV logs show `"Response body does not conform to a GraphQL response"` or `"Unexpected response for request on: /"`.
* **Cause**: `OPENAEV_XTM_OPENCTI_API_URL` is pointing to `http://opencti:8080` (root, returns HTML frontend) instead of the GraphQL endpoint.
* **Fix**: Change the API URL in `docker-compose.yml`:
    ```yaml
    # WRONG:
    - OPENAEV_XTM_OPENCTI_API_URL=http://opencti:8080
    # CORRECT:
    - OPENAEV_XTM_OPENCTI_API_URL=http://opencti:8080/graphql
    ```

### OpenCTI Schema Conflict (ElasticSearch 8)

**Symptoms**: `opencti` container loop or mapping errors in ES8 logs.
**Cause**: Legacy indices from failed installs preventing clean start.
**Fix**: Stop XTM, wipe ES8 data (`sudo rm -rf infra/vol/es8/data/*`), and restart.

* **Issue**: OpenAEV connector fails to register — `"input.id" is null` in OpenCTI logs but `OPENAEV_XTM_OPENCTI_ID` appears to be set.
* **Cause**: `OPENAEV_XTM_OPENCTI_ID` is missing from `.env` or not passed through `docker-compose.yml`.
* **Fix**: Ensure `.env` contains `OPENAEV_XTM_OPENCTI_ID=<valid-uuidv4>` and `docker-compose.yml` maps it:
    ```yaml
    - OPENAEV_XTM_OPENCTI_ID=${OPENAEV_XTM_OPENCTI_ID}
    ```

* **Issue**: PostgreSQL `Permission denied` errors in `infra-postgres` (especially after volume changes).
* **Cause**: The Alpine-based Postgres 17 image uses UID `70` (not `999`). If data directory ownership doesn't match, Postgres can't start.
* **Fix**: Run permissions fix:
    ```bash
    sudo chown -R 70:70 /opt/stacks/infra/vol/postgres-data
    ```

### MISP Modules
* **Issue**: Enrichment fails in MISP or FlowIntel.
* **Check**: ensure `misp-modules` stack is running and healthy: `curl http://localhost:6666/modules`.
* **Fix**: Check logs `docker logs misp-modules-shared`. Ensure `MISP_MODULES_FQDN` is set in `misp/docker-compose.yml` and `MISP_MODULES_URL` is set in `flowintel/docker-compose.yml`.

* **Issue**: Web UI shows "Instance of misp-modules is unreachable".
* **Cause**: The `misp-modules-web` container started before the API was healthy, or the API crashed.
* **Fix**: Restart the web UI: `docker compose restart misp-modules-web` (in `misp-modules/`). The `depends_on: service_healthy` should prevent this normally.

* **Issue**: Web UI returns `ValueError: SECRET_KEY must be set in .env`.
* **Fix**: Set `SECRET_KEY` in `misp-modules/.env`. Generate with: `openssl rand -hex 16`.

* **Issue**: FlowIntel enrichment fails but `misp-modules-shared` is healthy.
* **Cause**: FlowIntel bundles its own `misp-modules` process on `127.0.0.1:6666`. If the internal process dies, enrichment fails even though the shared instance is fine.
* **Check**: `docker exec flowintel-cti curl -s http://127.0.0.1:6666/modules | head -c 50`
* **Fix**: Restart flowintel: `docker compose restart flowintel` (in `flowintel/`).

### XTM Composer

* **Issue**: 403 Forbidden: `Failed to register into OpenAEV backend`
* **Symptoms**: `xtm-composer` logs show repeated `403` errors.
* **Cause**: The composer is using the wrong token to authenticate with OpenAEV (e.g., `${OPENCTI_ADMIN_TOKEN}` instead of `${OPENAEV_ADMIN_TOKEN}`).
* **Solution**: Ensure `OPENAEV__TOKEN` is set to `${OPENAEV_ADMIN_TOKEN}` in `xtm/docker-compose.yml` and redeploy.

* **Issue**: 500 Internal Server Error: `Failed to fetch connector instances`
* **Cause**: Transient issue. OpenAEV may return a 500 error if queried too early.
* **Solution**: Ignore it. The composer automatically retries.

### Shuffle

* **Issue**: Tenzir Load_TCP Error
* **Symptoms**: `shuffle-orborus` logs show errors when loading workflows, or `tenzir-node` crashes repeatedly.
* **Cause**: Incompatibility between Tenzir version and Shuffle's generated queries, or incorrect command launch for Tenzir v4+.
* **Solution**: 
  1. Use `tenzir/tenzir:v4.18.0` image.
  2. Set command in `docker-compose.yml`: `command: /opt/tenzir/bin/tenzir-node --endpoint=0.0.0.0:5160`.
  3. Set entrypoint to empty array: `entrypoint: []`.
  4. Ensure volume permissions are correct: `chown -R 1000:1000 ./vol/tenzir-lib`.

* **Issue**: OpenSearch Mapping Error: `No mapping found for [updated_at]`
* **Cause**: The `notifications` index was created without the correct schema mapping for the `updated_at` field.
* **Solution**: Manually apply the correct mapping to the index: `curl -X PUT "http://localhost:9200/notifications-000001/_mapping" ...`

* **Issue**: OpenSearch Startup Failure: `AccessDeniedException`
* **Cause**: Incorrect ownership of the mounted data directory (`vol/opensearch-data`).
* **Solution**: Fix ownership with `chown -R 1000:1000 vol/opensearch-data`.

* **Issue**: OpenSearch Connection Refused (HTTP vs HTTPS)
* **Cause**: Protocol mismatch or incorrect URL.
* **Solution**: Ensure `SHUFFLE_OPENSEARCH_URL=http://shuffle-opensearch:9200` in `.env`.

* **Issue**: Orborus Docker Client Error: `client version 1.40 is too old`
* **Cause**: `DOCKER_API_VERSION` env var is missing or set to an old value.
* **Solution**: Set `DOCKER_API_VERSION=1.44` in `.env`.

### MISP (Additional)

* **Issue**: Worker Fatal Error: `blpop() on null`
* **Symptoms**: Workers exit with FATAL state in Supervisord.
* **Cause**: `SimpleBackgroundJobs` plugin is not initializing the Redis connection correctly.
* **Solution**: Verify it is enabled in `app/Config/config.php` and verify environment variables aren't empty.

### Centralized Logging / Docker

* **Issue**: Disk Exhaustion
* **Symptoms**: Disk fills up rapidly, `docker logs` commands hang or are slow.
* **Cause**: Default Docker logging driver (`journald` or `json-file` without limits) can grow indefinitely.
* **Solution**: Check `/etc/docker/daemon.json` for log limits and run `docker system prune -f` or manually clear logs.

## Global Infrastructure Reset

### Deep Volume Wipe for Credential Sync

If you significantly change database passwords or encounter corrupted search clusters:

1. **Stop all stacks.**
2. **Postgres Reset**: `sudo rm -rf /opt/stacks/infra/vol/postgres/data/*` (Forces re-initialization of all DBs/Users via `init-dbs.sh`).
3. **Search Reset**: 
   - ES7: `sudo rm -rf /opt/stacks/infra/vol/es7/data/*`
   - ES8: `sudo rm -rf /opt/stacks/infra/vol/es8/data/*`
4. **Valkey Reset**: `sudo rm -rf /opt/stacks/infra/vol/valkey/data/*`
5. **Restart Infra**, then wait for healthy state before starting dependent stacks.

## Reverse Proxy & Network Changes

These issues arise when using the Caddy reverse proxy approach or after changing IPs/VLANs. See the [Reverse Proxy Guide](Reverse-Proxy-Guide.md) for full context.

### Stale Cached Address: `no route to host` After IP/VLAN Change

**Symptoms:**
- Service logs show `dial tcp <old-IP>:<port>: connect: no route to host`
- The IP in the error doesn't match your current `.env` configuration

**Cause:**
- Some services cache the server address at registration/first-boot time and never re-read the environment variable. The most common culprit is the **Forgejo runner**, which stores the address in `data/.runner`.

**Solution:**
1. Check for cached state files that may contain the old address: `cat forgejo-runner/data/.runner | grep address`
2. Delete the cached file and restart: `rm forgejo-runner/data/.runner && docker compose -f forgejo-runner/compose.yaml down && docker compose -f forgejo-runner/compose.yaml up -d`

> [!TIP]
> The Forgejo runner's `entrypoint.sh` now includes **automatic URL drift detection** — it compares the cached address against `GITEA_INSTANCE_URL` on every start and re-registers if they differ. See [forgejo-runner/README.md](../forgejo-runner/README.md).

### Service Cannot Resolve Domain Names

**Symptoms:**
- Service logs show DNS resolution failures for `*.lab.local` domains
- Service works with direct IPs but not domain names

**Cause:**
- The container is not attached to `cti-net`, so it uses the host's DNS resolver instead of Docker's internal DNS.

**Solution:**
1. Verify the service's `docker-compose.yml` has `networks: [cti-net]` assigned to the service (not just declared at the top level).
2. Restart the service.

### Caddy Returns 502 Bad Gateway

**Symptoms:**
- Browser shows `502 Bad Gateway` when accessing `service.lab.local`
- Caddy logs show `dial tcp: lookup <container-name>: no such host`

**Cause:**
- The backend container is not running or not on `cti-net`
- The container name in the Caddyfile doesn't match the actual container name

**Solution:**
1. Verify the backend is running: `docker ps | grep <container-name>`
2. Verify it's on `cti-net`: `docker network inspect cti-net | grep <container-name>`
3. Check the Caddyfile `reverse_proxy` target matches the container name and port
