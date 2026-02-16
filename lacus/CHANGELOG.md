# Changelog: Lacus Stack

## Build & Deployment (Feb 2026)

### Modifications
- **Dockerfile**:
  - Rewritten to use `ubuntu:24.04` base image.
  - Added explicit installation of `playwright` dependencies and `supervisor`.
  - Configured `LACUS_HOME` environment variable.
- **Configuration**:
  - Added automated config generation/validation scripts to build process.
- **Infrastructure**:
  - Uses external network `cti-net`.
  - Connects to shared `infra-valkey` (Redis).


### Fixes
- **Build Failure**: Resolved missing system dependencies for Playwright browsers by using a modern base image and explicit dependency installation.
- **Standardization**:
  - Added `.env.example` to the repository.
