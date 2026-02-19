# Wazuh Integration Guide

Since Wazuh runs in a separate LXC container (ID <WAZUH_ID>), you must configure the integration manually inside the container.

## 1. Access Wazuh Instance
```bash
pct enter <WAZUH_ID>
# OR
ssh root@192.168.x.195
```

## 2. Install TheHive Integration
Ensure python requests is installed (usually is).

## 3. Edit `ossec.conf`
File: `/var/ossec/etc/ossec.conf`

Add the following block to enable TheHive integration:

```xml
<integration>
  <name>thehive4</name>
  <hook_url>http://192.168.x.169:9000</hook_url> <!-- Docker Host IP -->
  <api_key>YOUR_THEHIVE_API_KEY</api_key>
  <alert_format>json</alert_format>
</integration>
```

*Note*: 
*   **Hook URL**: Points to TheHive on Docker Host (`192.168.x.169:9000`).
*   **API Key**: Generate this in TheHive (Admin > Users > Create Service Account).

## 4. Restart Wazuh Manager
```bash
systemctl restart wazuh-manager
```

## 5. Verify
Trigger an alert in Wazuh and check TheHive for new alerts.

# AIL Integration

AIL runs in Analysis Instance (`192.168.x.146`). The `ail-proxy` container on the Docker Host bridges traffic.

## 1. Access AIL Web UI
*   Primary: `http://192.168.x.169:7000` (Via Docker Host Proxy)
*   Direct: `http://192.168.x.146:7000` (If routing allows)

## 2. Generate API Key
*   Login to AIL.
*   Go to **Management** > **API Keys**.
*   Create a new key for Cortex/TheHive.

## 3. Configure Cortex (If using AIL Analyzers)
*   Go to Cortex UI (`http://192.168.x.198:9001`).
*   Login as Org Admin.
*   Go to **Organization** > **Analyzers**.
*   Find **AIL** analyzer.
*   Click **Enable**.
*   **URL**: `http://192.168.x.146:7000` (Direct instance IP usually best for Cortex-to-AIL).
*   **Key**: Paste the API Key from Step 2.
