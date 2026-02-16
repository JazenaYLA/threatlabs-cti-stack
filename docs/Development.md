# Development Guide

Welcome to the ThreatLabs CTI Stack development guide. This section is intended for contributors and users who wish to test changes, build new integrations, or run a local development instance alongside a production stack.

## 1. Environment Isolation

To prevent conflicts with production services, always use a custom project name and isolated database names for development.

### Project Naming
By default, the stack uses `COMPOSE_PROJECT_NAME=cti`. For development, it is recommended to set this to something unique in your `.env` file:
```bash
COMPOSE_PROJECT_NAME=cti-dev
```
This prefixes all containers with `cti-dev-` and creates an isolated network namespace.

### Database Naming
Use the following variables to point to development-specific databases on the shared infrastructure:
| Service | Variable | Default | Dev Recommended |
| :--- | :--- | :--- | :--- |
| OpenAEV | `OPENAEV_DB_NAME` | `openaev` | `dev_openaev` |
| n8n | `N8N_DB_NAME` | `n8n` | `dev_n8n` |
| FlowIntel | `FLOWINTEL_DB_NAME` | `flowintel` | `dev_flowintel` |

## 2. Environment Management Utility

We provide a utility script, `manage-env.sh`, to quickly switch between Production and Development states across all stacks.

### Switching Environments
- **To Production**:
  ```bash
  ./manage-env.sh prod
  ```
- **To Development**:
  ```bash
  ./manage-env.sh dev
  ```

### Managing Stacks
You can combine the environment switch with a Docker Compose command:
```bash
./manage-env.sh prod up      # Switch to prod and start all stacks
./manage-env.sh prod down    # Switch to prod and stop all stacks
./manage-env.sh status       # Show current active project name
```

## 3. Local Setup Process

1. **Clone the repository**:
   ```bash
   git clone <repo-url>
   cd cti-stack
   ```
2. **Initialize submodules**:
   ```bash
   git submodule update --init --recursive
   ```
3. **Run the setup script**:
   ```bash
   ./setup.sh
   ```
4. **Configure your `.env`**:
   Copy `.env.example` to `.env` in each stack and adjust variables for development.

## 3. Testing Changes

### Verifying Configuration
Before starting containers, verify the interpolated configuration:
```bash
docker compose config
```

### Checking Connectivity
Use the shared `cti-net` for all inter-service communication. You can verify network health with:
```bash
docker network inspect cti-net
```

## 4. Best Practices

- **Never commit `.env` files**: These contain sensitive credentials.
- **Use `.env.example` as a source of truth**: If you add a new variable, update the corresponding `.env.example`.
- **Clean up volumes**: When testing fresh installs, use `docker compose down -v` to remove named volumes (be careful not to target production volumes!).

---
For production deployment guides, see [Architecture](Architecture.md) and [Production Setup](Home.md).
