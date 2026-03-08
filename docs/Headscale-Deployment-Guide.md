# Headscale Zero-Trust Overlay (Enterprise)

This guide documents the setup and maintenance of the Zero-Trust overlay using **Headscale** (a self-hosted implementation of the Tailscale coordination server). This mesh securely bridges the CTI enclave (VLAN 101) with other networks like IoT/Home Automation (VLAN 107).

## 🏗️ Architecture

- **Control Plane**: Headscale running on **LXC 131**.
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
On the Headscale server:
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

## 📅 Roadmap tasks
- [ ] Configure automated node expiry.
- [ ] Enable OIDC/SSO for the Headscale control plane.
