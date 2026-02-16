# Changelog: TheHive Stack

## v4.x Integration (Feb 2026)

### Modifications
- **Docker Compose**: Added volume mount for local storage to prevent crash loops.
  - Mounted `./vol/thehive/data:/opt/thp/thehive/data`.
- **Configuration**: Updated `application.conf` (via UI/API) to connect to internal services on `cti-net`:
  - Cortex: `http://cortex:9001`
  - MISP: `http://misp-web:80`
- **Infrastructure**:
  - Uses external network `cti-net` for service discovery.
  - Relies on shared `infra-postgres` (Postgres 17) or `cassandra` (depending on version specific needs, here Cassandra).
  - Permissions fixed via `fix-permissions.sh` (UID 1000).
- **Environment**: Added `CORTEX_KEY` to `.env`.

### Fixes

### Fixes
- **Crash Loop**: Resolved `NoSuchFileException` by ensuring the data directory exists and is mounted.
- **Cortex**: Resolved restart loop caused by Elasticsearch connection and indexing issues (`index.max_result_window` limits).
- **Standardization**:
  - Added `.env.example` to the repository.
