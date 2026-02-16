# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased] - 2026-02-16

### Added
-   **Docker Socket Proxy**: Integrated `tecnativa/docker-socket-proxy` to securely expose the Docker socket to Shuffle Backend and Orborus.
-   **Configuration**: Added `DOCKER_API_VERSION` to `.env` to explicitly set the Docker API version for the Orborus client.

### Changed
-   **OpenSearch**: Updated `OPENSEARCH_VERSION` from `2.11.0` to `3.2.0` to resolve index format compatibility issues.
-   **Shuffle**: Updated `SHUFFLE_VERSION` to `2.2.0`.
-   **backend**: Changed `SHUFFLE_OPENSEARCH_URL` to use `http://` instead of `https://` to match the internal OpenSearch configuration.
-   **Tenzir**: Disabled `tenzir-node` by default (commented out in `docker-compose.yml`) to align with the standard Shuffle configuration. It remains documented as an optional service.

### Fixed
-   **Connectivity**: Resolved `connection refused` errors between Backend and OpenSearch by correcting the protocol.
-   **Permissions**: Fixed `AccessDeniedException` in OpenSearch by correcting ownership of `vol/opensearch-data` to UID 1000.
-   **Orborus**: Fixed "client version 1.40 is too old" error by forcing `DOCKER_API_VERSION=1.44`.
