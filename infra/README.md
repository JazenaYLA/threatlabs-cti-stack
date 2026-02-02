# Infrastructure Stack (infra)

This stack provides the shared core services required by the CTI ecosystem. It MUST be started first.

## Services

1. **ElasticSearch 7.17** (`es7-cti`): Legacy support for TheHive 4.
2. **ElasticSearch 8.19** (`es8-cti`): Modern support for Cortex 4, OpenCTI.
3. **Kibana 7 & 8**: Dashboards for respective ES versions.
4. **PostgreSQL 17** (`infra-postgres`): Shared relational database.
5. **Valkey** (`infra-valkey`): Shared Redis-compatible cache.

## Initialization

* **Database Init**: The `vol/postgres-init/init-dbs.sh` script runs on container startup to automatically create databases and users for dependent stacks:
  * `openaev` (User: `openaev`)
  * `n8n` (User: `n8n`)
  * `flowintel` (User: `flowintel`)

## Usage via Dockge

```bash
cd /opt/stacks/infra
# (Optional) Ensure volumes exist if not using setup.sh
./prepare-es-data.sh
# Start the stack
docker compose up -d
```

> **Note**: Allow time for ElasticSearch to initialize (green status) before starting dependent stacks like XTM or TheHive.
