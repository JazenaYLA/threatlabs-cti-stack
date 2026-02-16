#!/bin/bash

set -e
set -x

# /bin/bash -c 'cd /app/lacus/cache && ./run_redis.sh'

if [ ! -f /app/lacus/config/generic.json ]; then
    cd /app/lacus && poetry run python3 tools/validate_config_files.py --check
    cd /app/lacus && poetry run python3 tools/validate_config_files.py --update
fi

if [ ! -f /app/lacus/config/logging.json ]; then
    cp /app/lacus/config/logging.json.sample /app/lacus/config/logging.json
fi

/usr/bin/supervisord -c /supervisord/supervisord.conf