# Wazuh Stack Changelog

This document tracks changes, fixes, and deviations from the standard Wazuh Docker deployment for integration into the Homelab CTI stack.

## [4.11.0] - 2026-02-15

### Added
- **Manual Certificate Generation**:
    - *Issue*: The official `wazuh-certs-tool` download URL (v4.11) returned 403 Forbidden.
    - *Fix*: Created a custom `generate-certs.sh` using `openssl` to manually generate the Root CA and node certificates for Indexer, Manager, and Dashboard, ensuring correct Subject Alternative Names (SANs).
- **Custom Opensearch Config**:
    - *Issue*: The `wazuh-indexer:4.11.0` image comes with a default `opensearch.yml` pointing to `/etc/wazuh-indexer/certs`. However, the Java Security Manager policy within the container blocks access to `/etc`, causing crash loops (`AccessControlException`).
    - *Fix*: Extracted the default config, modified certificate paths to the allowed `/usr/share/wazuh-indexer/config/certs` directory, and mounted this custom `opensearch.yml` into the container.

### Changed
- **Version Downgrade**:
    - Reference repository used `5.0.0`, which does not exist on Docker Hub. Downgraded to stable `4.11.0`.
- **Port Remappings (Conflict Resolution)**:
    - **Indexer**: Remapped `9200` -> `9202` to avoid conflict with shared ElasticSearch 7 (`es7-cti`).
    - **Dashboard**: Remapped `5601` -> `5603` to avoid conflict with Kibana 7 (`kibana7-cti`) and Kibana 8 (`kibana8-cti`).
    - **Manager (Agents)**: Remapped `1514` -> `1516` to avoid conflict with Tenzir node (Shuffle stack).
- **Permissions**:
    - Integrated into `fix-permissions.sh` to forcefully set `1000:1000` ownership on `./vol` and `./wazuh-certificates`, as the containers run as `wazuh` user (UID 1000).

### Security
- **Credentials**:

    - Passwords for Indexer and API are sourced from `.env` instead of hardcoded defaults.
- **Standardization**:
    - Added `.env.example` to the repository for secure configuration management.
