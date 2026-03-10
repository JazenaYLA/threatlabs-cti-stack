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

### Volume Management (`volume-config.sh`)

The `scripts/volume-config.sh` script serves as the single source of truth for volume locations and permissions across all stacks. It is called by the main `setup.sh` to ensure consistency.

### Non-Destructive Environment Setup (`setup.sh`)

The `setup.sh` script now includes merging logic that backfills missing keys from `.env.example` templates into existing `.env` files. This allows for safe, non-destructive updates when new infrastructure variables are added.

- **Permission Fixes**: Automatically corrects UID/GID mismatches during initialization.
- **Dockge Link Refreshing**: Ensures that changes in stack structure are correctly reflected in the Dockge management UI.

### Permission Management (`fix-permissions.sh`)

Docker volumes for Postgres, Valkey, and ElasticSearch often suffer from UID/GID mismatches. This script automates the ownership fixes.

- **Location**: `scripts/fix-permissions.sh`
- **Usage**: Run before `docker compose up` if you see `Permission denied` errors in logs.

---

## 3. Environment Isolation

The stack uses a branch-aware deployment strategy to protect production data:

| Environment | Host Path | Branch | Logic |
|-------------|-----------|--------|-------|
| **Production** | `/opt/stacks` | `enterprise` | Headscale/Infisical Hardened |
| **Development** | `/opt/cti-dev` | `main` | Basic Homelab Version |

> [!WARNING]
> Do NOT run development tests in `/opt/stacks` as the Action Runner may overwrite your working persistent volume configurations.
