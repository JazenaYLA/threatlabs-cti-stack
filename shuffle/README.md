# Shuffle Stack

This directory contains the Docker Compose configuration for a self-hosted [Shuffle](https://shuffler.io) instance.

## Prerequisites

-   Docker Engine 20.10+
-   Docker Compose 2.0+

## Configuration

Configuration is managed via the `.env` file. Key variables include:

-   `SHUFFLE_VERSION`: Version of Shuffle to run (currently `2.2.0`).
-   `OPENSEARCH_VERSION`: Version of OpenSearch (currently `3.2.0`).
-   `DOCKER_API_VERSION`: Docker API version for the Orborus sidecar (set to `1.44` to avoid "client version too old" errors).
-   `SHUFFLE_OPENSEARCH_URL`: URL for Backend to connect to OpenSearch (http://shuffle-opensearch:9200).

## Architecture Changes

This deployment differs from the standard Shuffle installation in the following ways:

-   **Docker Socket Proxy**: Access to the Docker socket is mediated by `tecnativa/docker-socket-proxy` for improved security. Services communicate with Docker via `tcp://docker-socket-proxy:2375` instead of mounting `/var/run/docker.sock` directly.
-   **OpenSearch Protocol**: Configured to use HTTP (port 9200) internally to avoid SSL complexity within the internal network.

## Running the Stack

To start the stack:

```bash
docker compose up -d
```

To stop the stack:

```bash
docker compose down
```

## Troubleshooting

For common issues and fixes, please refer to the global [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) file in the parent directory.

## Integrated Services

### Tenzir (Optional)

The stack includes a [Tenzir](https://tenzir.com/) node (`tenzir-node`) which serves as a high-performance data pipeline and storage engine.

-   **Purpose**: Handles high-volume event logs and telemetry data that might overwhelm standard databases. It allows for ingest, storage, and querying of security event data.
-   **Ports**:
    -   `5160`: Tenzir API/Communication port.
    -   `1514`: Syslog ingestion (TCP/UDP).
-   **Divergence**: This service is explicitly defined with version `v4.18.0` to ensure compatibility with Shuffle's query engine, resolving potential version mismatch issues found in default configurations.
