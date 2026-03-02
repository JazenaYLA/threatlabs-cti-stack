# Welcome to the ThreatLabs CTI Project Wiki

This wiki documents the journey, architecture, and orchestration of our self-hosted Cyber Threat Intelligence (CTI) stack.

## 📚 Key Documents

- **[Architecture & Decisions](Architecture.md)**: Design choices, tradeoffs (networking, permissions), and shared infrastructure details.
- **[Reverse Proxy Guide](Reverse-Proxy-Guide.md)**: Setting up Caddy, migrating from direct IPs, and troubleshooting network changes.
- **[Troubleshooting Guide](Troubleshooting.md)**: Common issues and fixes for the stack.
- [Email Configuration Guide](Email-Configuration.md): Comprehensive guide for PMG and Stalwart Mail Flow configuration.
- [OPSEC Guide](OPSEC.md): Documentation hygiene rules for avoiding IP/credential leaks in public mirrors.

## ✍️ Blog Series

- **[Project Story & Timeline](blog/Project-Timeline.md)**: A chronological account of our build process, challenges, and orchestration decisions.
- **[Changelog](blog/Changelog.md)**: A high-level track of modifications across all stacks.
- **[AI Config Journal](blog/AI-Config-Journal.md)**: Troubleshooting journal for configuring systems over SSH using an AI coding agent.
- **[Narrative Arc](blog/Narrative-Arc.md)**: The pitfalls and discoveries of building the CTI stack.

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
