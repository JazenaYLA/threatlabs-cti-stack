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

## Kibana Monitoring

Monitor project indices using the following Data View patterns:

| Project | ES Cluster | Precise Index Pattern | Suggested Timestamp | Kibana Endpoint |
| :--- | :--- | :--- | :--- | :--- |
| **TheHive 4** | ES7 (Port 9200) | `scalligraph_global*` | `_createdAt` | [Kibana7](http://localhost:5601) |
| **Cortex 3** | ES8 (Port 9201) | `cortex*` | `createdAt` | [Kibana8](http://localhost:5602) |
| **OpenCTI** | ES8 (Port 9201) | `opencti_*` | `created_at` | [Kibana8](http://localhost:5602) |
| **OpenAEV** | ES8 (Port 9201) | `openaev_*` | `base_created_at` | [Kibana8](http://localhost:5602) |
| **Shuffle** | ES8 (Port 9201) | `shuffle__*` | `created` | [Kibana8](http://localhost:5602) |

> **Note**: Using these specific patterns ensures Kibana only queries relevant indices, saving cluster resources.
