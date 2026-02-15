# Changelog: MISP Stack

## Integration Updates (Feb 2026)

### Modifications
- **Docker Compose**:
  - Configured `cti-net` as external network.
  - Mounted `customize_misp.sh` hook to patch internal nginx configuration.
- **Networking**:
  - Renamed internal database service reference in *other* stacks to avoid conflict with MISP's `db` service on `cti-net`.
- **Infrastructure**:
  - Shared volume permissions managed by `fix-permissions.sh`.

### Fixes
- **HTTPS Redirect Loop**:
  - Patched nginx to be aware of the custom external port (`CORE_HTTPS_PORT`) to prevent infinite redirects when accessed via non-standard ports.
