# Headscale Zero-Trust Overlay (Enterprise)

This guide documents the setup and maintenance of the Zero-Trust overlay using **Headscale** (a self-hosted implementation of the Tailscale coordination server). This mesh securely bridges the CTI enclave (VLAN 101) with other networks like IoT/Home Automation (VLAN 107).

## 🏗️ Architecture

- **Control Plane**: Headscale running on **LXC 137**.
- **Nodes**: Dockge CTI Server, Home Assistant, and other authorized client devices.
- **Protocol**: WireGuard-based encrypted tunnels.
- **Purpose**: Replaces traditional SSH keys and port-forwarding with an audited, identity-based overlay.

## 🚀 Key Commands

### 1. Registering a New Node
On the client (laptop/desktop/LXC):
```bash
tailscale up --login-server http://<HEADSCALE_IP>:8080
```
This will provide a registration link. Copy the key and run on the Headscale server (LXC 131):
```bash
headscale nodes register --user <YOUR_USER> --key <REGISTRATION_KEY>
```

### 2. Monitoring the Mesh
On the Headscale server (LXC 137):
```bash
headscale nodes list
```

## 🛡️ Firewall & Security Policy

To maintain a secure "Zero-Trust" posture, cross-VLAN communication must be aggressively restricted at the router (UniFi/pfSense/OPNsense) to prevent pivot attacks.

### 🧱 Required Pinhole Rules (IoT -> CTI)
Allow ONLY the following traffic from your Home Assistant/IoT IP to the Headscale LXC:

| Protocol | Destination Port | Intent |
| :--- | :--- | :--- |
| **TCP** | `8080` | API Handshake / Control Plane |
| **UDP** | `3478` | STUN/DERP payload encryption (WireGuard wrapper) |

### 🚫 Global Block Policy
- **Action**: DROP/DENY
- **Source**: `IoT_Subnet` (VLAN 107)
- **Destination**: `CTI_Subnet` (VLAN 101)
- **Rule Intent**: Ensures that while devices can broker a WireGuard session, no standard local traffic can reach the backend CTI databases or Web UIs directly.

## 🛡️ Hardening (Phase 4)

### 1. Automated Node Expiry
To prevent "zombie" nodes from persisting in the mesh, configure the OIDC expiry in `config.yaml`:
```yaml
oidc:
  # Sets the default expiry for OIDC-authenticated nodes (e.g., 30 days)
  expiry: 30d
  # Or use the OIDC token's own expiry (short-lived, more secure, but more prompts)
  use_expiry_from_token: false
```
*Note*: For "Gateway" nodes that should never expire, manually set their expiry to NULL in the Headscale DB (SQLite/Postgres).

### 2. OIDC / SSO Integration (Authentik/Keycloak)
Enable the `oidc` block to enforce identity-based authentication:
```yaml
oidc:
  issuer: "https://auth.<DOMAIN>/application/o/headscale/"
  client_id: "<CLIENT_ID>"
  client_secret: "<CLIENT_SECRET>"
  scope: ["openid", "profile", "email"]
```

## 📅 Roadmap tasks
- [x] Configure automated node expiry.
- [x] Enable OIDC/SSO for the Headscale control plane.
- [ ] Implement group-based ACLs for cross-VLAN isolation.
