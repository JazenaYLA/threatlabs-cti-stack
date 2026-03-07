# Welcome to the ThreatLabs CTI Project Wiki

This wiki documents the journey, architecture, and orchestration of our self-hosted Cyber Threat Intelligence (CTI) stack.

## 📚 Key Documents

- **[Architecture & Decisions](Architecture.md)**: Design choices, tradeoffs (networking, permissions), and shared infrastructure details.
- **[Reverse Proxy Guide](Reverse-Proxy-Guide.md)**: Setting up Caddy, migrating from direct IPs, and troubleshooting network changes.
- **[Troubleshooting Guide](Troubleshooting.md)**: Common issues and fixes for the stack.
- **[Email Configuration Guide](Email-Configuration.md)**: Comprehensive guide for PMG and Stalwart Mail Flow configuration.
- **[Infisical Secret Management (Advanced)](Infisical-Integration-Guide.md)**: Guide for dynamically injecting secrets at runtime to replace plaintext `.env` files.
- **[Headscale Zero-Trust Overlay (Enterprise)](Headscale-Pending-Tasks.md)**: Pending tasks and firewall requirements for the Tailscale mesh.

## 🏗️ Stack Overview

Our environment consists of several integrated stacks:

- **TheHive**: Security Incident Response Platform.
- **MISP**: Malware Information Sharing Platform.
- **Lacus**: URL capture and analysis service.
- **DFIR-IRIS**: Collaborative incident response.
- **Wazuh**: SIEM and XDR.
- **Flowintel/Flowise/n8n**: Orchestration and automation.
- **Email Gateway**: **PMG** (LXC) for hygiene and **Stalwart** (LXC) for internal service accounts.

## 🔧 Standardization

- All stacks now use `.env.example` as the standard for environment variable templates.
