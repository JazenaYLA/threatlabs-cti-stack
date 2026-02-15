# Changelog: DFIR-IRIS Stack

## Initial Deployment (Feb 2026)

### New Features
- **Webhooks Module**:
  - Baked into custom Docker image (extends official `iriswebapp_app`) via `pip install iris_webhooks_module`.
  - Module pre-registered on first boot.

### Modifications
- **Docker Compose**:
  - Completely custom `docker-compose.yml` (flattened from upstream).
  - Explicitly sets `POSTGRES_SERVER=iris-db` to avoid DNS conflict with MISP on shared network.
  - Uses bind mounts (`./vol/`) instead of named volumes.
- **Configuration**:
  - Added `DB_RETRY_COUNT=30` to `.env` to prevent startup timeouts.
  - configured `CELERY_BROKER=amqp://iris-rabbitmq` in `.env`.
- **security**:
  - Auto-generation of self-signed certificates in `setup.sh`.
  - Strong random secrets generated in `.env`.

### Fixes
- **Database Timeout**: App failed to connect during Postgres init; added retry logic.
- **DNS Conflict**: App connected to MISP DB (172.19.x.x) instead of IRIS DB (172.20.x.x); fixed by renaming service reference.
- **Permissions**: Fixed Nginx startup failure due to unreadable certificate keys (UID permissions).
