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
ln -s /path/to/repo/thehive4-cortex4-n8n/docker-compose.yml thehive
```

### MISP feed fetch is stuck / Queue full

**Cause**: Initial fetch of all feeds can overload workers.
**Solution**:

1. Increase workers in **Administration > Server Settings > Workers**.
2. Restart workers: `sudo supervisorctl restart all` (inside container).

## Specific Stack Issues

### Cortex

* **Issue**: Cortex cannot connect to ElasticSearch.
* **Check**: Does `infra` have `es8-cti` running? Cortex 4 requires ES (often ES7 or ES8 depending on config, here configured for ES8).
* **Fix**: Update `cortex` service env `es_uri` to point to `http://es8-cti:9200`.

### TheHive

* **Issue**: TheHive cannot connect to ElasticSearch.
* **Check**: TheHive 4 requires **ElasticSearch 7**.
* **Fix**: Ensure `es7-cti` service in `infra` is healthy and env `ES_HOSTS` points to `es7-cti:9200`.

### OpenCTI

* **Issue**: Connectors not showing up or "rabbitmq" connection refused.
* **Check**: Is the shared RabbitMQ in `xtm` healthy?
* **Fix**: Check `xtm` logs: `docker compose logs -f rabbitmq`.
