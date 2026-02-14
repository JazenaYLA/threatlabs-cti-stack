# CTI Stack Troubleshooting Guide

This guide addresses common issues encountered when deploying the ThreatLabs CTI stack on Proxmox/Dockge.

## Quick Checks Sequence

If something isn't working, check these in order:

1. **Network Check**: Is `cti-net` active?

    ```bash
    docker network ls | grep cti-net
    ```

    *Fix*: Run `./setup.sh` or `docker network create cti-net`.

2. **Infrastructure Health**: Are ElasticSearch nodes ready?

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

* **Issue**: Redis continuously restarts/crashes in LXC.
* **Cause**: ZFS file system incompatibility with Redis persistence.
* **Fix**: Disable `use_direct_io_for_flush_and_compaction` in `redis.conf`. See `ail-project/README.md` for the full fix.

### TheHive

* **Issue**: TheHive cannot connect to ElasticSearch.
* **Check**: TheHive 4 requires **ElasticSearch 7**.
* **Fix**: Ensure `es7-cti` service in `infra` is healthy and env `ES_HOSTS` points to `es7-cti:9200`.

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

