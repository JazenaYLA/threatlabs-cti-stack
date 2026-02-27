#!/bin/bash
# customize_misp.sh — runs after MISP init completes
# Patches nginx for Caddy reverse proxy support:
#  - Skips redirect patch when DISABLE_SSL_REDIRECT is set (Caddy handles TLS)
#  - Falls back to port redirect for direct HTTPS access

MISP80="/etc/nginx/sites-enabled/misp80"

# When behind Caddy, SSL redirect is disabled — skip patching
if [[ "${DISABLE_SSL_REDIRECT}" == "true" ]]; then
    echo "Customize | SSL redirect disabled (Caddy mode) — skipping nginx redirect patch"
    exit 0
fi

# Patch redirect to include non-standard HTTPS port
if [[ -n "$CORE_HTTPS_PORT" && "$CORE_HTTPS_PORT" != "443" && -f "$MISP80" ]]; then
    echo "Customize | Patching nginx redirect to include port $CORE_HTTPS_PORT"
    sed -i "s|return 301 https://\$host\$request_uri;|return 301 https://\$host:${CORE_HTTPS_PORT}\$request_uri;|" "$MISP80"
    nginx -s reload 2>/dev/null || true
fi
