#!/bin/bash
set -e

echo "=== MISP Modules Web Interface ==="

# Initialize SQLite database if it doesn't exist
if [ ! -f /app/instance/misp-module.sqlite ]; then
    echo "[+] Initializing database..."
    python3 -c "
from app import create_app, db
from app.utils import gen_admin_password

app = create_app()
with app.app_context():
    db.create_all()
    gen_admin_password()
    print('[+] Database tables created.')

    # Populate modules from external API
    from app.utils.init_modules import create_modules_db
    create_modules_db()
    print('[+] Module list populated.')
"
    echo "[+] Database initialized."
else
    echo "[*] Database already exists, skipping init."
fi

echo "[+] Starting gunicorn on 0.0.0.0:${FLASK_PORT:-7008}..."
exec gunicorn -k gevent -w 4 -b "0.0.0.0:${FLASK_PORT:-7008}" "main:app"
