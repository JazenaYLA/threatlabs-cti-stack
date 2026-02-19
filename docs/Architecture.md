# Architecture & Decisions

This document chronicles the journey of integrating multiple Cyber Threat Intelligence (CTI) platforms—**TheHive**, **MISP**, **Lacus**, and **DFIR-IRIS**—into a unified, self-hosted homelab environment. It details the challenges, tradeoffs, and architectural decisions made to ensure these distinct stacks work together harmoniously.

## 🏗️ Shared Infrastructure

### The Network Challenge
**Goal**: Allow independent stacks to communicate (e.g., TheHive -> MISP, IRIS -> MISP) without exposing everything to the host network or creating a massive monolithic compose file.

**Solution**:  
We created a dedicated external Docker network, `cti-net`.
- **Decision**: All stacks define `cti-net` as `external: true`.
- **Tradeoff**: You must ensure the network exists (`docker network create cti-net`) before bringing up any stack.
- **Benefit**: Seamless service discovery by container name across stacks (e.g., `es7-cti` reachable by TheHive).

### Permission Management
**Challenge**: Different containers run as different users (Postgres=999, Elastic=1000, Root=0), causing "Permission Denied" errors on bind-mounted volumes.
**Solution**:  
Created `fix-permissions.sh`.
- **Logic**: Iterates through known data directories and forcefully applies the correct UID/GID (`chown -R`).
- **Automation**: Integrated into the setup process to ensure a clean start.

## 🧱 Stack-Specific Chronicles

For detailed technical changes, fixes, and version-specific modifications, refer to the individual changelogs:

- **[TheHive Changelog](thehive/CHANGELOG.md)**: Crash loops, Cortex integration, and storage fixes.
- **[MISP Changelog](misp/CHANGELOG.md)**: HTTPS redirect patches, database conflicts, and hook systems.
- **[Lacus Changelog](lacus/CHANGELOG.md)**: Build system rewrite, Playwright dependencies, and Redis integration.
- **[DFIR-IRIS Changelog](dfir-iris/CHANGELOG.md)**: Custom webhooks module build, database connectivity endurance, and certificate management.
- **[Wazuh Changelog](wazuh/CHANGELOG.md)**: Manual certificate generation, port conflict resolution (9202/5603), and Opensearch config patching.

## 🛡️ Stability & Isolation (Feb 2026 Update)

### The Action Runner Risk
**Challenge**: Automated deployments to the `main` branch were performing "destructive syncs," overwriting local `.env` fixes and causing unnecessary service restarts in production.

**Solution**:  
Implemented a **Branch-Aware Deployment Strategy**.
- **Isolation**: Created a separate filesystem root (`/opt/cti-dev`) for experimental work.
- **Logic**: Pushes to `auto-swapper` automatically sync to the dev root; pushes to `main` are decoupled from automatic automation.
- **Safety**: Production updates now require a manual `workflow_dispatch` trigger, ensuring that manual hotfixes and database states are preserved during normal development cycles.

## 🚀 Summary of Tradeoffs

1.  **Complexity vs. Isolation**: We chose **Shared Networking** over complete isolation. This simplifies integration (direct IP connectivity) but requires careful naming (DNS conflicts).
2.  **Standards vs. Customization**: We modified upstream `docker-compose.yml` files significantly (flattened structures, added build steps). This means "git pull" updates from upstream require manual merging, but gives us a stable, tailored homelab environment.
3.  **Security**: We generated self-signed certs for internal HTTPS. This requires trusting the CA in your browser but encrypts traffic on the wire.

---
*Created by Antigravity Assistant - Feb 2026*
