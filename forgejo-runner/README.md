# Forgejo Action Runner

Deployment runner for the CTI Stack ecosystem.

## Environment Separation

The runner is configured to support two distinct environments on the same host:

- **Production** (`/opt/stacks`): Persistent stack managed via the `main` branch.
- **Development** (`/opt/cti-dev`): Experimental stack managed via the `auto-swapper` branch.

## Deployment Logic (`deploy.yml`)

The GitHub Actions workflow implements branch-aware synchronization:

- **Pushes to `auto-swapper`**: Automatically syncs the repository to `/opt/cti-dev` and restarts only the development containers.
- **Pushes to `main`**: Automatic deployment is **DISABLED** for production safety. Production updates require manual trigger via `workflow_dispatch` to prevent unnecessary service restarts and database rebuilds.

## Isolated Runner Configuration

The runner container (`forgejo-runner/compose.yaml`) has isolated access to both environments via separate volume mounts:

```yaml
volumes:
  - /opt/stacks:/opt/stacks
  - /opt/cti-dev:/opt/cti-dev
```

This prevents the development runner from accidentally modifying production files outside its designated root.
