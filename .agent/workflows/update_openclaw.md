---
description: Update OpenClaw from your Fork and rebuild
---

1. Navigate to the OpenClaw directory

   ```bash
   cd openclaw
   ```

2. Pull latest changes from your Fork (origin)

   ```bash
   git pull origin main
   ```

   > **Note**: Ensure you have synced your Fork with the original Upstream repo (e.g., using GitHub's "Sync Fork" button) before running this.

3. Rebuild the Docker container

   ```bash
   docker compose up -d --build
   ```

4. Notify user of status

   ```bash
   echo "OpenClaw updated from Fork. Containers rebuilt."
   ```
