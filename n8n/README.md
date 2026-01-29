# n8n Automation Workflows

This stack is designed to be the "Automation Engine" for your CTI pipeline.

## Planned Workflow: "CTI Content Generator"

This workflow automatically fetches vetted intelligence and turns it into social media content and blog posts.

### 1. Trigger

* **Cron**: Runs every 30 minutes.
* **Logic**: Checks MISP or OpenCTI for items tagged `tweet:ready` or `blog:ready`.

### 2. Ingestion & Enrichment

* **Node**: HTTP Request (MISP/OpenCTI API).
* **Action**: Pulls full event details (IOCs, description, tags).
* **Enrichment**: Can optionally query AIL API (`http://ail-proxy:7000/api/v1/query/`) for related leaks.

### 3. AI Processing (Flowise)

* **Node**: HTTP Request (Flowise API).
* **Endpoint**: `http://flowise:3000/api/v1/prediction/<YOUR_FLOW_ID>`.
* **Payload**: The raw CTI JSON.
* **Agent**: "Jamz CTI Explainer" (configured in Flowise).
* **Output**:
  * A Tweet-length summary.
  * A Short blog post draft (Markdown).

### 4. Publication

* **X (Twitter)**: Posts the thread using your API credentials.
* **Ghost Blog**: Drafts a new post via Ghost Admin API.

## Configuration Requirements

1. **Credentials**: Store API keys for MISP, OpenCTI, and Twitter in n8n **Credentials** store.
2. **Flowise**: Create your "CTI Explainer" chatflow in Flowise first, then copy the API endpoint ID.
