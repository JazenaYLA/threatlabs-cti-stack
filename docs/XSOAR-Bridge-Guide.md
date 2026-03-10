# Phase 3: The Enterprise Bridge (XSOAR)

This guide documents the architecture and deployment of the **Enterprise Bridge**, designed to allow secure, audited communication between the ThreatLabs Homelab CTI stack and professional Cortex XSOAR environments.

## 🏗️ Architecture

The bridge utilizes a **Cortex XSOAR Remote Engine** (D1) deployed on a dedicated node within the CTI enclave.

- **Bridge Node**: A dedicated Linux LXC or VM.
- **Engine Role**: Acts as a proxy, initiating outbound connections to the XSOAR tenant and executing integrations/scripts against the local CTI stack.
- **Auditing**: All actions are logged at the engine level and can be further audited via optional **Teleport** integration for administrative access.

## 🚀 Deployment Steps

### 1. Provision the Bridge Node
- Recommended: Ubuntu 22.04+ or Debian 11+ LXC.
- Requirements: Docker or Podman installed.
- Resources: 2 vCPU, 4GB RAM minimum for engine stability.

### 2. Install the XSOAR Engine
- Download the engine installer from your Cortex XSOAR instances (`Settings -> Integrations -> Engines`).
- Execute the installer on the Bridge Node:
  ```bash
  chmod +x ./d1_installer.sh
  sudo ./d1_installer.sh
  ```
- Configure the engine to use the local CTI proxy if necessary by editing `/usr/local/demisto/d1.conf`.

### 3. Networking & Firewall

The bridge node requires a "restricted conduit" posture:

| Traffic Direction | Protocol | Port | Destination | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **Outbound** | TCP | `443` | `XSOAR_TENANT_URL` | Control Plane & Heartbeat |
| **Internal** | TCP | `443` / `8080` | `CTI_SERVICES_IPS` | Integration API calls (MISP, OpenCTI, etc.) |

## 🛡️ Hardening & Compliance

- **No Inbound from Enterprise**: The engine MUST initiate all traffic. No inbound firewall rules from the Internet or Enterprise WAN should be opened.
- **RBAC**: Use XSOAR integration instances with "least privilege" API keys (Read-only where possible).
- **Professional Auditing (Teleport)**: 
  - Deploy the **Teleport Proxy** in **Recording Proxy Mode** to intercept and record all SSH sessions to the bridge node.
  - This ensures that even if users bypass standard controls, a searchable, bit-for-bit record of the terminal session is maintained for professional compliance audits.
  - Enable **AI Session Summaries** in Teleport to provide high-level visibility into bridge activities without manual review of every session.

## 📅 Roadmap tasks
- [ ] Verify connectivity through the Caddy Reverse Proxy.
- [ ] Configure log shipping from the engine to the central Wazuh SIEM.
