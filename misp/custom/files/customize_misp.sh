#!/bin/bash
# customize_misp.sh — runs after MISP init completes
# Patches nginx HTTP→HTTPS redirect to use the correct external HTTPS port.
#
# Docker maps CORE_HTTP_PORT→80 and CORE_HTTPS_PORT→443, so nginx listen
# directives stay at 80/443. Only the redirect URL needs the external port.

MISP80="/etc/nginx/sites-enabled/misp80"

# Patch redirect to include non-standard HTTPS port
if [[ -n "$CORE_HTTPS_PORT" && "$CORE_HTTPS_PORT" != "443" && -f "$MISP80" ]]; then
    echo "Customize | Patching nginx redirect to include port $CORE_HTTPS_PORT"
    sed -i "s|return 301 https://\$host\$request_uri;|return 301 https://\$host:${CORE_HTTPS_PORT}\$request_uri;|" "$MISP80"
    nginx -s reload 2>/dev/null || true
fi
