#!/usr/bin/env bash
#
# Lookyloo Production Deployment Script for Proxmox LXC (Ubuntu 24.04+)
# Follows official multi-user production requirements
# Reference: https://www.lookyloo.eu/docs/main/install-lookyloo-production.html
#
# Prerequisites:
#   - Ubuntu 24.04+ LXC container (unprivileged recommended)
#   - Container features: nesting=1 (for proper systemd support)
#   - Minimum 4GB RAM, 2-4 CPU cores, 50GB storage
#   - Run as root user in the LXC container
#
# Usage: 
#   chmod +x deploy_lookyloo_lxc.sh && sudo ./deploy_lookyloo_lxc.sh
#

set -e  # Exit on error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "\n${CYAN}========================================${NC}\n${BLUE}$1${NC}\n${CYAN}========================================${NC}"; }

# ============================================
# Configuration Variables
# ============================================
LOOKYLOO_USER="lookyloo"
LOOKYLOO_GROUP="lookyloo"
LOOKYLOO_HOME="/home/$LOOKYLOO_USER"
INSTALL_DIR="$LOOKYLOO_HOME/gits"
LOOKYLOO_REPO="https://github.com/Lookyloo/lookyloo.git"
UWHOISD_REPO="https://github.com/Lookyloo/uwhoisd.git"
VALKEY_REPO="https://github.com/valkey-io/valkey"
VALKEY_VERSION="8.0"
PYTHON_VERSION="3.12"

# Feature toggles
INSTALL_UWHOISD="true"              # Universal WHOIS support (recommended)
REMOTE_LACUS_ENABLE="false"         # Set to "true" to use existing Lacus instance
REMOTE_LACUS_URL=""                 # e.g., "http://192.168.x.x:7100"
REVERSE_PROXY="nginx"               # Options: "nginx", "traefik", or "none"
SETUP_TLS="false"                   # Enable for Let's Encrypt setup (requires valid domain)
DOMAIN_OR_IP="localhost"            # Change to your domain/IP

# Traefik integration (if using existing Traefik)
TRAEFIK_NETWORK="cti-net"           # Docker network name
TRAEFIK_HOST=""                     # e.g., "lookyloo.yourdomain.com"

# Log retention
LOG_RETENTION_DAYS="14"             # Days to keep rotated logs

# ============================================
# Pre-flight Checks
# ============================================
log_section "Lookyloo Production Deployment - Ubuntu 24.04 LXC"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root"
   log_error "Usage: sudo $0"
   exit 1
fi

# Verify we're in an LXC container (default user context is root)
log_info "Current user: $(whoami)"
log_info "Current directory: $(pwd)"

# Check Ubuntu version
if ! grep -q "Ubuntu" /etc/os-release; then
    log_warn "This script is optimized for Ubuntu 24.04+. Detected: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2)"
    read -r -p "Continue anyway? [y/N]: " CONFIRM
    if [[ ! "$CONFIRM" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        exit 1
    fi
fi

# Check if running in LXC
if [ -d /dev/.lxc ]; then
    log_info "✓ LXC container detected"
else
    log_warn "Not running in LXC container. This script is designed for Proxmox LXC."
fi

# Display configuration
log_info "Configuration Summary:"
echo "  Install Directory: $INSTALL_DIR"
echo "  Python Version: $PYTHON_VERSION"
echo "  Lookyloo User: $LOOKYLOO_USER (will be created)"
echo "  uwhoisd: $([ "$INSTALL_UWHOISD" = "true" ] && echo "✓ Enabled" || echo "✗ Disabled")"
echo "  Remote Lacus: $([ "$REMOTE_LACUS_ENABLE" = "true" ] && echo "✓ Enabled ($REMOTE_LACUS_URL)" || echo "✗ Using LacusCore")"
echo "  Reverse Proxy: $REVERSE_PROXY"
echo "  Domain/IP: $DOMAIN_OR_IP"
echo "  Log Retention: $LOG_RETENTION_DAYS days"
echo ""

read -r -p "Proceed with installation? [y/N]: " CONFIRM
if [[ ! "$CONFIRM" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    log_info "Installation cancelled by user"
    exit 0
fi

# ============================================
# 1. System Updates and Base Dependencies
# ============================================
log_section "Step 1/12: System Updates & Dependencies"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential \
    tcl \
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-dev \
    python${PYTHON_VERSION}-venv \
    python3-pip \
    git \
    curl \
    wget \
    whois \
    sudo \
    logrotate \
    ca-certificates \
    gnupg \
    lsb-release

# Install nginx if needed
if [ "$REVERSE_PROXY" = "nginx" ]; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y nginx
fi

log_info "Base dependencies installed"

# ============================================
# 2. Create Lookyloo System User
# ============================================
log_section "Step 2/12: Creating Lookyloo System User"

if id "$LOOKYLOO_USER" &>/dev/null; then
    log_warn "User $LOOKYLOO_USER already exists"
else
    # Create user with home directory and bash shell
    useradd -m -s /bin/bash "$LOOKYLOO_USER"
    log_info "✓ User $LOOKYLOO_USER created"
fi

# Verify home directory exists and has correct ownership
if [ ! -d "$LOOKYLOO_HOME" ]; then
    log_error "Home directory $LOOKYLOO_HOME does not exist after user creation"
    exit 1
fi

# Ensure proper ownership of home directory
chown -R "$LOOKYLOO_USER:$LOOKYLOO_GROUP" "$LOOKYLOO_HOME"
log_info "✓ Home directory ownership set"

# Create installation directory
mkdir -p "$INSTALL_DIR"
chown -R "$LOOKYLOO_USER:$LOOKYLOO_GROUP" "$INSTALL_DIR"
log_info "✓ Installation directory created: $INSTALL_DIR"

# Initialize shell profile for lookyloo user
if [ ! -f "$LOOKYLOO_HOME/.bashrc" ]; then
    log_warn ".bashrc missing, copying from /etc/skel"
    cp /etc/skel/.bashrc "$LOOKYLOO_HOME/.bashrc"
    chown "$LOOKYLOO_USER:$LOOKYLOO_GROUP" "$LOOKYLOO_HOME/.bashrc"
fi

# Verify we can switch to lookyloo user
if ! su - "$LOOKYLOO_USER" -c "pwd" &>/dev/null; then
    log_error "Cannot switch to $LOOKYLOO_USER user context"
    exit 1
fi
log_info "✓ User context verified"

# ============================================
# 3. Install Poetry (as lookyloo user)
# ============================================
log_section "Step 3/12: Installing Poetry"

# Check if poetry already installed
if su - "$LOOKYLOO_USER" -c "command -v poetry" &>/dev/null; then
    POETRY_VERSION=$(su - "$LOOKYLOO_USER" -c "poetry --version" 2>/dev/null || echo "unknown")
    log_info "Poetry already installed: $POETRY_VERSION"
else
    log_info "Installing Poetry for $LOOKYLOO_USER..."

    # Install poetry as lookyloo user
    su - "$LOOKYLOO_USER" <<'POETRY_INSTALL'
set -e
export HOME="$HOME"
curl -sSL https://install.python-poetry.org | python3 -
POETRY_INSTALL

    # Add Poetry to PATH in .bashrc if not already present
    if ! grep -q ".local/bin" "$LOOKYLOO_HOME/.bashrc"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$LOOKYLOO_HOME/.bashrc"
        log_info "✓ Poetry PATH added to .bashrc"
    fi

    # Verify Poetry installation
    if su - "$LOOKYLOO_USER" -c 'export PATH="$HOME/.local/bin:$PATH"; poetry --version' &>/dev/null; then
        POETRY_VERSION=$(su - "$LOOKYLOO_USER" -c 'export PATH="$HOME/.local/bin:$PATH"; poetry --version')
        log_info "✓ Poetry installed: $POETRY_VERSION"
    else
        log_error "Poetry installation failed"
        exit 1
    fi
fi

# Get Poetry path for systemd service (will be used later)
POETRY_BIN=$(su - "$LOOKYLOO_USER" -c 'export PATH="$HOME/.local/bin:$PATH"; which poetry' 2>/dev/null || echo "$LOOKYLOO_HOME/.local/bin/poetry")
log_info "Poetry binary path: $POETRY_BIN"

# ============================================
# 4. Install Valkey 8.0 from Source
# ============================================
log_section "Step 4/12: Building Valkey 8.0"

if [ -d "$INSTALL_DIR/valkey" ]; then
    log_warn "Valkey directory exists, skipping clone..."
else
    log_info "Cloning and compiling Valkey 8.0..."

    su - "$LOOKYLOO_USER" <<VALKEY_INSTALL
set -e
cd "$INSTALL_DIR"
git clone --branch "$VALKEY_VERSION" --depth 1 "$VALKEY_REPO"
cd valkey
make -j\$(nproc)
echo "Valkey compilation complete"
VALKEY_INSTALL

    log_info "✓ Valkey 8.0 compiled successfully"
fi

# ============================================
# 5. Install uwhoisd (Optional)
# ============================================
if [ "$INSTALL_UWHOISD" = "true" ]; then
    log_section "Step 5/12: Installing uwhoisd (Universal WHOIS)"

    if [ -d "$INSTALL_DIR/uwhoisd" ]; then
        log_warn "uwhoisd directory exists, skipping clone..."
    else
        log_info "Installing uwhoisd..."

        su - "$LOOKYLOO_USER" <<UWHOISD_INSTALL
set -e
export PATH="$HOME/.local/bin:\$PATH"
cd "$INSTALL_DIR"
git clone "$UWHOISD_REPO"
cd uwhoisd
poetry install
echo "UWHOISD_HOME=\"\$(pwd)\"" > .env
echo "uwhoisd installation complete"
UWHOISD_INSTALL

        log_info "✓ uwhoisd installed"
    fi

    # Create systemd service for uwhoisd
    log_info "Creating uwhoisd systemd service..."

    cat > /etc/systemd/system/uwhoisd.service <<UWHOISD_SERVICE
[Unit]
Description=Universal WHOIS Service for Lookyloo
After=network.target

[Service]
User=$LOOKYLOO_USER
Group=$LOOKYLOO_GROUP
Type=simple
WorkingDirectory=$INSTALL_DIR/uwhoisd
Environment="PATH=$LOOKYLOO_HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="HOME=$LOOKYLOO_HOME"
ExecStart=$POETRY_BIN run start
Restart=on-failure
RestartSec=10
StandardOutput=append:/var/log/uwhoisd_message.log
StandardError=append:/var/log/uwhoisd_error.log

[Install]
WantedBy=multi-user.target
UWHOISD_SERVICE

    # Create log files with proper ownership
    touch /var/log/uwhoisd_message.log /var/log/uwhoisd_error.log
    chown "$LOOKYLOO_USER:$LOOKYLOO_GROUP" /var/log/uwhoisd_message.log /var/log/uwhoisd_error.log

    systemctl daemon-reload
    systemctl enable uwhoisd
    systemctl start uwhoisd
    sleep 2

    if systemctl is-active --quiet uwhoisd; then
        log_info "✓ uwhoisd service started successfully"
    else
        log_warn "⚠ uwhoisd service may need manual check: systemctl status uwhoisd"
    fi
else
    log_section "Step 5/12: Skipping uwhoisd (disabled)"
fi

# ============================================
# 6. Clone and Install Lookyloo
# ============================================
log_section "Step 6/12: Installing Lookyloo"

if [ -d "$INSTALL_DIR/lookyloo" ]; then
    log_warn "Lookyloo directory exists, pulling latest..."
    su - "$LOOKYLOO_USER" <<LOOKYLOO_UPDATE
cd "$INSTALL_DIR/lookyloo"
git pull || echo "Git pull failed, continuing with existing version"
LOOKYLOO_UPDATE
else
    log_info "Cloning Lookyloo repository..."
    su - "$LOOKYLOO_USER" <<LOOKYLOO_CLONE
set -e
cd "$INSTALL_DIR"
git clone "$LOOKYLOO_REPO"
LOOKYLOO_CLONE
fi

log_info "Installing Lookyloo dependencies (this may take several minutes)..."

su - "$LOOKYLOO_USER" <<LOOKYLOO_INSTALL
set -e
export PATH="$HOME/.local/bin:\$PATH"
cd "$INSTALL_DIR/lookyloo"

# Set LOOKYLOO_HOME environment variable
echo "LOOKYLOO_HOME=\"$INSTALL_DIR/lookyloo\"" > .env

# Install Python dependencies
echo "Running poetry install..."
poetry install --no-interaction

# Install Playwright dependencies and browsers
echo "Installing Playwright browsers..."
poetry run playwright install-deps
poetry run playwright install
echo "Lookyloo installation complete"
LOOKYLOO_INSTALL

log_info "✓ Lookyloo installation complete"

# ============================================
# 7. Configure Lookyloo
# ============================================
log_section "Step 7/12: Configuring Lookyloo"

su - "$LOOKYLOO_USER" <<LOOKYLOO_CONFIG
set -e
export PATH="$HOME/.local/bin:\$PATH"
cd "$INSTALL_DIR/lookyloo"

# Copy sample configs if they don't exist
[ ! -f config/generic.json ] && cp config/generic.json.sample config/generic.json
[ ! -f config/modules.json ] && cp config/modules.json.sample config/modules.json

echo "Configuration files initialized"
LOOKYLOO_CONFIG

# Configure remote Lacus if enabled (as root since we're modifying files)
if [ "$REMOTE_LACUS_ENABLE" = "true" ]; then
    log_info "Configuring remote Lacus at: $REMOTE_LACUS_URL"
    python3 <<PYCONFIG
import json
config_path = "$INSTALL_DIR/lookyloo/config/generic.json"
with open(config_path, 'r') as f:
    config = json.load(f)
config['remote_lacus'] = {
    'enable': True,
    'url': '$REMOTE_LACUS_URL'
}
with open(config_path, 'w') as f:
    json.dump(config, f, indent=2)
print("Remote Lacus configured")
PYCONFIG
fi

# Enable uwhoisd module if installed
if [ "$INSTALL_UWHOISD" = "true" ]; then
    log_info "Enabling uwhoisd module..."
    python3 <<PYUWHOIS
import json
modules_path = "$INSTALL_DIR/lookyloo/config/modules.json"
with open(modules_path, 'r') as f:
    modules = json.load(f)
if 'UniversalWhois' in modules:
    modules['UniversalWhois']['enabled'] = True
    print("UniversalWhois module enabled")
with open(modules_path, 'w') as f:
    json.dump(modules, f, indent=2)
PYUWHOIS
fi

# Ensure proper ownership after configuration
chown -R "$LOOKYLOO_USER:$LOOKYLOO_GROUP" "$INSTALL_DIR/lookyloo/config"

# Pull 3rd party dependencies
log_info "Pulling 3rd party dependencies..."
su - "$LOOKYLOO_USER" <<LOOKYLOO_UPDATE_DEPS
set -e
export PATH="$HOME/.local/bin:\$PATH"
cd "$INSTALL_DIR/lookyloo"
poetry run update --yes || echo "Update completed with warnings"
LOOKYLOO_UPDATE_DEPS

log_info "✓ Lookyloo configured"

# ============================================
# 8. Setup Systemd Service
# ============================================
log_section "Step 8/12: Creating Systemd Service"

cat > /etc/systemd/system/lookyloo.service <<SYSTEMD_SERVICE
[Unit]
Description=Lookyloo Web Forensics Platform
Documentation=https://www.lookyloo.eu/docs/
After=network.target
$([ "$INSTALL_UWHOISD" = "true" ] && echo "Wants=uwhoisd.service" || echo "")
$([ "$INSTALL_UWHOISD" = "true" ] && echo "After=uwhoisd.service" || echo "")

[Service]
User=$LOOKYLOO_USER
Group=$LOOKYLOO_GROUP
Type=forking
WorkingDirectory=$INSTALL_DIR/lookyloo
Environment="PATH=$LOOKYLOO_HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="HOME=$LOOKYLOO_HOME"
Environment="LOOKYLOO_HOME=$INSTALL_DIR/lookyloo"
ExecStart=$POETRY_BIN run start
ExecStop=$POETRY_BIN run stop
ExecReload=$POETRY_BIN run restart
Restart=on-failure
RestartSec=10
StandardOutput=append:/var/log/lookyloo_message.log
StandardError=append:/var/log/lookyloo_error.log

[Install]
WantedBy=multi-user.target
SYSTEMD_SERVICE

# Create log files with proper ownership
touch /var/log/lookyloo_message.log /var/log/lookyloo_error.log
chown "$LOOKYLOO_USER:$LOOKYLOO_GROUP" /var/log/lookyloo_message.log /var/log/lookyloo_error.log

systemctl daemon-reload
log_info "✓ Systemd service created"

# ============================================
# 9. Setup Reverse Proxy
# ============================================
log_section "Step 9/12: Configuring Reverse Proxy ($REVERSE_PROXY)"

if [ "$REVERSE_PROXY" = "nginx" ]; then
    cat > /etc/nginx/sites-available/lookyloo <<'NGINX_CONFIG'
server {
    listen 80;
    server_name DOMAIN_PLACEHOLDER;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Proxy to Lookyloo
    location / {
        proxy_pass http://127.0.0.1:5100;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Timeouts for long-running captures
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }
}
NGINX_CONFIG

    # Replace domain placeholder
    sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN_OR_IP/g" /etc/nginx/sites-available/lookyloo

    # Enable site
    rm -f /etc/nginx/sites-enabled/default
    ln -sf /etc/nginx/sites-available/lookyloo /etc/nginx/sites-enabled/

    nginx -t && systemctl restart nginx && systemctl enable nginx
    log_info "✓ Nginx configured on port 80"

elif [ "$REVERSE_PROXY" = "traefik" ]; then
    log_info "Traefik integration mode"

    # Create traefik labels file for reference
    cat > "$INSTALL_DIR/lookyloo/traefik-labels.txt" <<TRAEFIK_LABELS
# Traefik Labels for Docker Integration
# Add these labels if running Lookyloo in Docker, or configure Traefik manually

traefik.enable=true
traefik.http.routers.lookyloo.rule=Host(\`$TRAEFIK_HOST\`)
traefik.http.services.lookyloo.loadbalancer.server.port=5100
$([ "$SETUP_TLS" = "true" ] && echo "traefik.http.routers.lookyloo.tls.certresolver=letsencrypt" || echo "")

# For LXC integration with Docker Traefik:
# 1. Connect container to Docker network: docker network connect $TRAEFIK_NETWORK <container>
# 2. Add Traefik configuration pointing to this LXC IP:5100
TRAEFIK_LABELS

    chown "$LOOKYLOO_USER:$LOOKYLOO_GROUP" "$INSTALL_DIR/lookyloo/traefik-labels.txt"
    log_warn "⚠ Traefik labels saved to: $INSTALL_DIR/lookyloo/traefik-labels.txt"
    log_warn "⚠ Manual Traefik configuration required"

else
    log_info "No reverse proxy configured - Lookyloo will be accessible on port 5100"
fi

# ============================================
# 10. Setup Log Rotation
# ============================================
log_section "Step 10/12: Configuring Log Rotation"

LOGS_TO_ROTATE="/var/log/lookyloo_message.log /var/log/lookyloo_error.log"
[ "$INSTALL_UWHOISD" = "true" ] && LOGS_TO_ROTATE="$LOGS_TO_ROTATE /var/log/uwhoisd_message.log /var/log/uwhoisd_error.log"

cat > /etc/logrotate.d/lookyloo <<LOGROTATE
$LOGS_TO_ROTATE {
    daily
    missingok
    rotate $LOG_RETENTION_DAYS
    compress
    delaycompress
    notifempty
    create 0640 $LOOKYLOO_USER $LOOKYLOO_GROUP
    sharedscripts
    postrotate
        systemctl reload lookyloo > /dev/null 2>&1 || true
        $([ "$INSTALL_UWHOISD" = "true" ] && echo "systemctl reload uwhoisd > /dev/null 2>&1 || true" || echo "")
    endscript
}
LOGROTATE

log_info "✓ Log rotation configured (${LOG_RETENTION_DAYS} days retention)"

# ============================================
# 11. TLS/SSL Setup (Optional)
# ============================================
if [ "$SETUP_TLS" = "true" ] && [ "$REVERSE_PROXY" = "nginx" ]; then
    log_section "Step 11/12: Setting up Let's Encrypt TLS"

    if [ "$DOMAIN_OR_IP" = "localhost" ] || [[ "$DOMAIN_OR_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_warn "⚠ TLS requires a valid domain name. Skipping TLS setup."
        log_warn "Current DOMAIN_OR_IP: $DOMAIN_OR_IP"
    else
        apt-get install -y certbot python3-certbot-nginx
        certbot --nginx -d "$DOMAIN_OR_IP" --non-interactive --agree-tos --register-unsafely-without-email
        log_info "✓ Let's Encrypt TLS configured for $DOMAIN_OR_IP"
    fi
else
    log_section "Step 11/12: TLS Setup Skipped"
    log_warn "⚠ TLS not configured. Recommended for production deployments."
fi

# ============================================
# 12. Start Services
# ============================================
log_section "Step 12/12: Starting Services"

systemctl enable lookyloo
systemctl start lookyloo
sleep 5

if systemctl is-active --quiet lookyloo; then
    log_info "✓ Lookyloo service is running"
else
    log_error "✗ Lookyloo service failed to start"
    log_error "Check logs: journalctl -u lookyloo -n 50 --no-pager"
    log_error "Or: tail -f /var/log/lookyloo_error.log"
fi

# ============================================
# Post-Installation Summary
# ============================================
log_section "Installation Complete!"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                  Lookyloo Deployment Summary                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "📂 Installation:"
echo "   Directory:  $INSTALL_DIR/lookyloo"
echo "   User:       $LOOKYLOO_USER"
echo "   Home:       $LOOKYLOO_HOME"
echo ""
echo "🌐 Access URLs:"
if [ "$REVERSE_PROXY" = "nginx" ]; then
    echo "   HTTP:       http://$DOMAIN_OR_IP/"
    [ "$SETUP_TLS" = "true" ] && echo "   HTTPS:      https://$DOMAIN_OR_IP/"
elif [ "$REVERSE_PROXY" = "traefik" ]; then
    echo "   Via Traefik: $TRAEFIK_HOST (configure Traefik manually)"
    echo "   Direct:      http://<LXC-IP>:5100/"
else
    echo "   Direct:     http://<LXC-IP>:5100/"
fi
echo ""
echo "🔧 Services:"
echo "   Lookyloo:   systemctl {start|stop|status|restart} lookyloo"
[ "$INSTALL_UWHOISD" = "true" ] && echo "   uwhoisd:    systemctl {start|stop|status} uwhoisd"
echo ""
echo "📝 Logs:"
echo "   Lookyloo:   tail -f /var/log/lookyloo_message.log"
[ "$INSTALL_UWHOISD" = "true" ] && echo "   uwhoisd:    tail -f /var/log/uwhoisd_message.log"
echo "   Systemd:    journalctl -u lookyloo -f"
echo ""
echo "⚙️  Configuration:"
echo "   Generic:    $INSTALL_DIR/lookyloo/config/generic.json"
echo "   Modules:    $INSTALL_DIR/lookyloo/config/modules.json"
echo ""
echo "🔐 Features:"
echo "   Remote Lacus: $([ "$REMOTE_LACUS_ENABLE" = "true" ] && echo "✓ Enabled ($REMOTE_LACUS_URL)" || echo "✗ Using LacusCore")"
echo "   uwhoisd:      $([ "$INSTALL_UWHOISD" = "true" ] && echo "✓ Enabled" || echo "✗ Disabled")"
echo "   TLS/SSL:      $([ "$SETUP_TLS" = "true" ] && echo "✓ Enabled" || echo "✗ Disabled")"
echo ""
echo "⚠️  Next Steps:"
echo "   1. Review configuration files for customization"
echo "   2. $([ "$SETUP_TLS" != "true" ] && echo "Setup TLS/SSL for production (certbot)" || echo "✓ TLS already configured")"
echo "   3. Configure additional modules in config/modules.json"
if [ "$REVERSE_PROXY" = "traefik" ]; then
    echo "   4. Configure Traefik to route to this LXC at port 5100"
    echo "   5. Optional: docker network connect $TRAEFIK_NETWORK <container>"
else
    echo "   4. Configure firewall rules if needed"
fi
echo ""
echo "📚 Documentation: https://www.lookyloo.eu/docs/main/"
echo ""

# Save installation summary
cat > /root/lookyloo-info.txt <<INFO
Lookyloo Installation Summary
==============================
Installed: $(date)
Installation Directory: $INSTALL_DIR/lookyloo
Service User: $LOOKYLOO_USER
User Home: $LOOKYLOO_HOME
Poetry Path: $POETRY_BIN

Access:
  $([ "$REVERSE_PROXY" = "nginx" ] && echo "URL: http://$DOMAIN_OR_IP/" || echo "Direct: http://<LXC-IP>:5100/")

Configuration Files:
  $INSTALL_DIR/lookyloo/config/generic.json
  $INSTALL_DIR/lookyloo/config/modules.json

Service Management:
  systemctl {start|stop|restart|status} lookyloo
  $([ "$INSTALL_UWHOISD" = "true" ] && echo "systemctl {start|stop|status} uwhoisd" || echo "")

Logs:
  /var/log/lookyloo_message.log
  /var/log/lookyloo_error.log
  $([ "$INSTALL_UWHOISD" = "true" ] && echo "/var/log/uwhoisd_message.log" || echo "")
  $([ "$INSTALL_UWHOISD" = "true" ] && echo "/var/log/uwhoisd_error.log" || echo "")

Troubleshooting:
  journalctl -u lookyloo -n 50 --no-pager
  tail -f /var/log/lookyloo_error.log
  su - $LOOKYLOO_USER
  cd $INSTALL_DIR/lookyloo && poetry run status
INFO

log_info "✓ Installation info saved to: /root/lookyloo-info.txt"
echo ""
