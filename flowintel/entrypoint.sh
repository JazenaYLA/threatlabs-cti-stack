#!/bin/bash
set -e

echo "Checking if PostgreSQL server is up..."

# CHANGED: Use environment variables instead of hardcoded postgresql:5432
/home/flowintel/app/bin/wait-for-it.sh "${DB_HOST:-postgresql}:${DB_PORT:-5432}" --timeout=30 --strict -- echo "Postgres is up"

# Inject Custom Admin Credentials if provided
if [ -n "$INIT_ADMIN_EMAIL" ] || [ -n "$INIT_ADMIN_PASSWORD" ]; then
    echo "Injecting custom admin credentials..."
    python3 - <<EOF
import os
conf_path = "/home/flowintel/app/conf/config.py"
with open(conf_path, "r") as f:
    content = f.read()

# Add INIT_ADMIN_USER if missing or update it
if "INIT_ADMIN_USER =" not in content:
    # Inject into Config class
    injection = f"""
    INIT_ADMIN_USER = {{
        "first_name": "admin",
        "last_name": "admin",
        "email": "{os.getenv('INIT_ADMIN_EMAIL', 'admin@admin.admin')}",
        "password": "{os.getenv('INIT_ADMIN_PASSWORD', 'admin')}"
    }}
"""
    # Find end of Config class properties (heuristic: look for class DevelopmentConfig)
    if "class DevelopmentConfig" in content:
        content = content.replace("class DevelopmentConfig", injection + "\nclass DevelopmentConfig")
    else:
        # Fallback: append to Config class (assuming it's at top)
        content = content.replace("class Config:", "class Config:" + injection)
else:
    # If it exists (e.g. from default copy), use regex or simpler replace if structure is known
    # But since we saw it missing, appending is safer.
    pass

with open(conf_path, "w") as f:
    f.write(content)

# Also patch init_db.py to FORCE the use of env vars by replacing hardcoded values
init_db_path = "/home/flowintel/app/app/utils/init_db.py"
if os.path.exists(init_db_path):
    with open(init_db_path, "r") as f:
        init_content = f.read()
    
    # Ensure os is imported
    if "import os" not in init_content:
        init_content = "import os\n" + init_content

    # Replace hardcoded admin email
    if 'email="admin@admin.admin"' in init_content:
       init_content = init_content.replace(
           'email="admin@admin.admin"', 
           "email=os.getenv('INIT_ADMIN_EMAIL', 'admin@admin.admin')"
       )
       
    # Replace hardcoded admin password
    if 'password="admin"' in init_content:
        init_content = init_content.replace(
            'password="admin"',
            "password=os.getenv('INIT_ADMIN_PASSWORD', 'admin')"
        )
        
    with open(init_db_path, "w") as f:
        f.write(init_content)

EOF
fi

sleep 2

echo "Postgres is reachable. Checking for database '$DB_NAME'..."

DB_EXISTS=$(python3 - << 'EOF'
import os, psycopg2
try:
    conn = psycopg2.connect(
        host=os.getenv("DB_HOST", "postgresql"),
        port=os.getenv("DB_PORT", "5432"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
        dbname=os.getenv("DB_NAME"),
        connect_timeout=3
    )
    cur = conn.cursor()
    cur.execute('SELECT id FROM "user" WHERE first_name = %s;', ("admin",))
    result = cur.fetchone()
    exists = result is not None
    print("1" if exists else "0")
except Exception as e:
    # print(e) # Debug
    print("0")
EOF
)

if [ "$DB_EXISTS" = "1" ]; then
    echo "Database/User already exists."
else
    echo "Database missing — running initialization..."
    bash -i /home/flowintel/app/launch.sh -id
fi

exec bash -i /home/flowintel/app/launch.sh -ld
