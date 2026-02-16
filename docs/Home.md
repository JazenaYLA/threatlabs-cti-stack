# Welcome to the ThreatLabs CTI Project Wiki

This wiki documents the journey, architecture, and orchestration of our self-hosted Cyber Threat Intelligence (CTI) stack.

## 📚 Key Documents

- **[Project Story & Timeline](Project-Timeline.md)**: A chronological account of our build process, challenges, and orchestration decisions.
- [Architecture](Architecture.md) - Design decisions and network topology.
- [Development Guide](Development.md) - Local setup, testing, and environment isolation.
- [External LXC Services](../internal_ips.md) - Connectivity details for Wazuh/OpenClaw.
- **[Troubleshooting Guide](Troubleshooting.md)**: Common issues and fixes for the stack.
- **[Changelog](Changelog.md)**: A high-level track of modifications across all stacks.

## 🏗️ Stack Overview

Our environment consists of several integrated stacks:
- **TheHive**: Security Incident Response Platform.
- **MISP**: Malware Information Sharing Platform.
- **Lacus**: URL capture and analysis service.
- **DFIR-IRIS**: Collaborative incident response.
- **Wazuh**: SIEM and XDR.
- **Flowintel/Flowise/n8n**: Orchestration and automation.

## 🔧 Standardization

- All stacks now use `.env.example` as the standard for environment variable templates.
