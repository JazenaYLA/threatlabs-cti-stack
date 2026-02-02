#!/bin/bash
set -e

# Function to create user and database
create_db_and_user() {
	local database=$1
	local user=$2
	local password=$3
	echo "  Creating user '$user' and database '$database'..."
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
	    CREATE USER $user WITH PASSWORD '$password';
	    CREATE DATABASE $database;
	    GRANT ALL PRIVILEGES ON DATABASE $database TO $user;
	    \c $database
	    GRANT ALL ON SCHEMA public TO $user;
EOSQL
}

# Databases to create (Default passwords matched to .env.examples)
# Note: Ideally these passwords should be pulled from secure env vars, 
# but for init we use defaults which user can override via mapped script if needed.
# Since we are inside the container, we rely on the primary superuser to create them.

echo "XXX Creating Additional Databases XXX"

# OpenAEV / OpenCTI
# Note: OpenCTI often uses Elastic, but OpenAEV needs Postgres.
create_db_and_user "openaev" "openaev" "changeme"

# n8n
create_db_and_user "n8n" "n8n" "n8npass123!"

# FlowIntel
create_db_and_user "flowintel" "flowintel" "changeme"

echo "XXX Databases created XXX"
