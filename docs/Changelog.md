# Project Changelog

Tracking high-level modifications and standardization efforts across the ThreatLabs CTI project.

## [Unreleased]

### Added
- **Docs**: Created `docs/` directory formatted as a Forgejo Wiki (`Home.md`, `Project-Timeline.md`, `Changelog.md`).
- **Docs**: Added `docs/` to `.gitignore` to keep it local for now.
- **Standardization**: Added `.env.example` files for `wazuh` and `misp` stacks.
- **Standardization**: Renamed root `.env.sample` to `.env.example`.

### Changed
- **Wazuh**: Standardized environment variables.
- **MISP**: Standardized environment variables.

### [2026-02-27]

#### Added
- **Reverse Proxy**: Migrated from hardcoded IPs to Caddy domain-based routing (`*.lab.local`) across all stacks.
- **Docs**: Created `docs/Reverse-Proxy-Guide.md` covering both direct IP and proxy approaches with migration steps.
- **Forgejo Runner**: Added `entrypoint.sh` with **URL drift detection** — automatically re-registers when `GITEA_INSTANCE_URL` changes.
- **Forgejo Runner**: Added `cti-net` network attachment (was declared but never assigned to service).
- **Troubleshooting**: Added reverse proxy/network change troubleshooting section to `TROUBLESHOOTING.md`.

#### Fixed
- **Forgejo Runner**: Resolved `no route to host` error caused by stale cached address in `data/.runner` file (hardcoded IP instead of `forgejo.lab.local`).

### [2026-02-19]

#### Added
- **Environment Isolation**: Implemented a dual-root strategy (/opt/stacks for PROD, /opt/cti-dev for DEV) to prevent environment cross-contamination.
- **Action Runner**: Implemented branch-aware deployment logic in `deploy.yml`:
  - `auto-swapper` branch -> Automatic deployment to `/opt/cti-dev`.
  - `main` branch -> Automatic production deployment **DISABLED** for safety.
- **Runner Configuration**: Added volume mount for `/opt/cti-dev` to the Forgejo Runner.
- **Documentation**: Formalized technical lessons on MISP healthchecks, Cassandra permissions, and ElasticSearch schema recovery.

#### Fixed
- **MISP**: Resolved internal healthcheck 403 failures by aligning application and database credentials.
- **TheHive**: Fixed Cassandra startup loop via recursive UID <ID> ownership fix on data volumes.
- **XTM**: Resolved OpenCTI schema conflicts via deep ElasticSearch 8 data wipe and re-initialization.
- **Infrastructure**: Fixed shared database initialization by wiping legacy Postgres volumes.
