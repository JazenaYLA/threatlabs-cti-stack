# Headscale Pending Tasks

As part of the **ThreatLabs CTI** enterprise architecture, we established a Tailscale mesh overlay network powered by a self-hosted **Headscale** control plane on `192.168.101.151`. The core ThreatLabs CTI server (`192.168.101.169`) was successfully registered to this mesh, giving it a secure `100.64.0.1` overlay IP.

The following items are deferred and must be completed to finalize the Zero-Trust network layer across the homelab subnets.

## 1. Connect Home Assistant to the Mesh (Deferred)

The Home Assistant (HA) node physically resides on the IoT VLAN (107) at `192.168.107.50`. To grant it secure, zero-trust access to the ThreatLabs CTI network (e.g., to fetch MQTT passwords from the Infisical Vault), it must join the Tailscale mesh.

**Steps to execute when ready:**

1. Open the Proxmox Host shell and enter the Home Assistant LXC.
2. Install the Tailscale daemon using the helper script:

   ```bash
   bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/addon/add-tailscale-lxc.sh)"
   ```

3. Join the Headscale control plane:

   ```bash
   tailscale up --login-server=http://192.168.101.151:8080
   ```

4. Verify on the Headscale server (`192.168.101.151`):

   ```bash
   headscale nodes list
   ```

## 2. Configure Pinhole Firewall Rules

Once Home Assistant is actively joining the `.101` Headscale server, cross-VLAN communication must be aggressively restricted at the router (pfSense/OPNsense/UniFi) to prevent compromised IoT devices from pivoting into the CTI enclave.

**Required Pinhole Policy:**

* **Action:** ALLOW
* **Source:** `192.168.107.50` (Home Assistant IP only)
* **Destination:** `192.168.101.151` (Headscale LXC IP only)
* **Ports:** TCP `8080` (API handshake) and UDP `3478` (STUN/DERP payload encryption)

**Required Global Block Policy:**

* **Action:** DROP/DENY
* **Source:** `192.168.107.0/24` (IoT Subnet)
* **Destination:** `192.168.101.0/24` (CTI Subnet)
* **Rule Intent:** Ensures that while HA can broker a WireGuard session over UDP, no standard TCP/UDP traffic from IoT can reach the backend CTI databases or Web UIs directly.
