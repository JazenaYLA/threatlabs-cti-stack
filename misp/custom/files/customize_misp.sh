#!/bin/bash
# customize_misp.sh — runs after MISP init completes
# Fixes the HTTP→HTTPS redirect to include the correct host port

# Only patch if CORE_HTTPS_PORT is set and not the default (443)
if [[ -n "$CORE_HTTPS_PORT" && "$CORE_HTTPS_PORT" != "443" ]]; then
    MISP80="/etc/nginx/sites-enabled/misp80"
    if [[ -f "$MISP80" ]]; then
        echo "Customize | Patching nginx redirect to include port $CORE_HTTPS_PORT"
        sed -i "s|return 301 https://\$host\$request_uri;|return 301 https://\$host:${CORE_HTTPS_PORT}\$request_uri;|" "$MISP80"
        nginx -s reload 2>/dev/null || true
    fi
fi
