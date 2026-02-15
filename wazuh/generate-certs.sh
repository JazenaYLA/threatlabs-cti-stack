#!/bin/bash
set -e

# Wazuh Certs Generation Script (Manual OpenSSL)
# Replaces wazuh-certs-tool due to download issues.

CERTS_DIR="wazuh-certificates"
mkdir -p "$CERTS_DIR"

echo "[*] Generating Root CA..."
openssl req -x509 -new -nodes -extensions v3_ca -keyout "$CERTS_DIR/root-ca.key" -out "$CERTS_DIR/root-ca.pem" -days 3650 -subj "/C=US/ST=California/L=San Jose/O=Wazuh/CN=Wazuh Root CA"

# Function to generate cert
gen_cert() {
    NAME=$1
    CN=$2
    SAN=$3 # DNS:...,IP:...

    echo "[*] Generating cert for $NAME ($CN)..."

    # Key
    openssl genrsa -out "$CERTS_DIR/$NAME-key.pem" 2048

    # CSR
    openssl req -new -key "$CERTS_DIR/$NAME-key.pem" -out "$CERTS_DIR/$NAME.csr" -subj "/C=US/ST=California/L=San Jose/O=Wazuh/OU=Wazuh/CN=$CN"

    # Extfile for SAN
    echo "subjectAltName=$SAN" > "$CERTS_DIR/$NAME.ext"

    # Sign with Root CA
    openssl x509 -req -in "$CERTS_DIR/$NAME.csr" -CA "$CERTS_DIR/root-ca.pem" -CAkey "$CERTS_DIR/root-ca.key" -CAcreateserial -out "$CERTS_DIR/$NAME.pem" -days 3650 -extfile "$CERTS_DIR/$NAME.ext"

    # Cleanup
    rm "$CERTS_DIR/$NAME.csr" "$CERTS_DIR/$NAME.ext"
    
    # Check permissions
    chmod 644 "$CERTS_DIR/$NAME.pem"
    chmod 640 "$CERTS_DIR/$NAME-key.pem"
}

# Admin Cert
# Note: Admin usually doesn't need SANs, but good practice.
gen_cert "admin" "admin" "DNS:admin,DNS:wazuh.indexer"

# Indexer Cert
# Must match hostname wazuh.indexer
gen_cert "wazuh.indexer" "wazuh.indexer" "DNS:wazuh.indexer,DNS:localhost,IP:127.0.0.1"

# Manager Cert
gen_cert "wazuh.manager" "wazuh.manager" "DNS:wazuh.manager,DNS:localhost,IP:127.0.0.1"

# Dashboard Cert
gen_cert "wazuh.dashboard" "wazuh.dashboard" "DNS:wazuh.dashboard,DNS:localhost,IP:127.0.0.1"

echo "[+] Certificates generated in $CERTS_DIR."
# Ensure read access
chmod -R 755 "$CERTS_DIR"
