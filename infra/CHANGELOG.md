# Changelog: Shared Infrastructure

## CTI Homelab Setup (Feb 2026)

### Networking
- **`cti-net`**: Created distinct docker network (`docker network create cti-net`) used by all stacks (TheHive, MISP, IRIS, etc.) to allow internal service discovery by container name.

### Automation
- **`setup.sh`**:
  - Automated volume creation for all stacks.
  - Automated self-signed certificate generation (DFIR-IRIS).
  - Automated random secret generation.
- **`fix-permissions.sh`**:
  - Centralized permission management.
  - Handles UID/GID mapping for different services (Postgres=999, Elastic=1000, etc.).

  - Handles UID/GID mapping for different services (Postgres=999, Elastic=1000, etc.).

### Components
- **Vaultwarden**:
  - Deployed Vaultwarden for password management, integrated with Traefik using file provider.
- **OpenClaw**:
  - Configured Traefik proxy with `openclaw-headers` and `openclaw-ipwhitelist` middlewares.
- **Standardization**:
  - Added `.env.example` to the repository.
