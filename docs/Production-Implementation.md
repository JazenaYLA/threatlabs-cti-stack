# Production Implementation Guide

This guide covers host-level configurations and automation scripts required for a stable, production-ready deployment of the ThreatLabs CTI Stack.

## 1. Host Preparation

The services in this stack (especially ElasticSearch and Wazuh) require specific host-level kernel settings.

### ElasticSearch Kernel Tuning
ElasticSearch uses a `mmapfs` directory by default to store its indices. The default operating system limits on mmap counts is likely to be too low.

Run the following command as root to increase the limit:
```bash
sysctl -w vm.max_map_count=262144
```
To make this change permanent, add the following line to `/etc/sysctl.conf`:
```text
vm.max_map_count=262144
```

### File Descriptor Limits
Ensure your host allows a sufficient number of open file descriptors for the Docker daemon:
```bash
ulimit -n 65535
```

---

## 2. Automation & "Janitor" Scripts

The `scripts/` directory contains essential tools for maintaining stack health.

### Permission Management (`fix-permissions.sh`)
Docker volumes for Postgres, Valkey, and ElasticSearch often suffer from UID/GID mismatches. This script automates the ownership fixes.
- **Location**: `scripts/fix-permissions.sh`
- **Usage**: Run before `docker compose up` if you see `Permission denied` errors in logs.

### Certificate Generation (`generate-certs.sh`)
Wazuh and other TLS-strict services require custom certificates with specific Subject Alternative Names (SANs).
- **Location**: `scripts/wazuh-certs/generate-certs.sh`
- **Why**: The official automated tools often fail in "Shared External Network" (`cti-net`) environments. This script hand-crafts the `openssl` requirements.

---

## 3. Environment Isolation

The stack uses a branch-aware deployment strategy to protect production data:

| Environment | Host Path | Branch | Logic |
|-------------|-----------|--------|-------|
| **Production** | `/opt/stacks` | `main` | Manual Trigger Only |
| **Development** | `/opt/cti-dev` | `dev/*` | Auto-Synchronized |

> [!WARNING]
> Do NOT run development tests in `/opt/stacks` as the Action Runner may overwrite your working persistent volume configurations.
