#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Main menu
echo
echo -e "${PURPLE}============================${NC}"
echo -e "${WHITE}MARZBAN INSTALLATION SCRIPT${NC}"
echo -e "${PURPLE}============================${NC}"
echo
echo -e "${CYAN}Please select installation type:${NC}"
echo
echo -e "${GREEN}1.${NC} Install Panel"
echo -e "${GREEN}2.${NC} Install Node"
echo -e "${RED}3.${NC} Exit"
echo
echo -ne "${CYAN}Enter your choice (1, 2, or 3): ${NC}"
read INSTALL_TYPE

case $INSTALL_TYPE in
    1)
        echo
        echo -e "${GREEN}Starting Panel installation...${NC}"
        echo
        ;;
    2)
        echo
        echo -e "${GREEN}Starting Node installation...${NC}"
        echo
        ;;
    3)
        echo
        echo -e "${YELLOW}Exiting installation. Goodbye!${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid choice. Please select 1, 2, or 3.${NC}"
        exit 1
        ;;
esac

# Panel Installation

if [ "$INSTALL_TYPE" = "1" ]; then

# Marzban Panel setup

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Checking root permissions
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}This command must be run as root.${NC}"
    exit 1
fi

# Domain validation
validate_domain() {
    local domain=$1
    if [[ "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] && [[ ! "$domain" =~ [[:space:]] ]]; then
        return 0
    fi
    return 1
}

# IPv4 validation
validate_ip() {
    local ip=$1
    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        return 0
    fi
    return 1
}

# Command execution check
check_command() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Error: $1${NC}"
        exit 1
    fi
}

echo
echo -e "${PURPLE}====================${NC}"
echo -e "${WHITE}MARZBAN PANEL SETUP${NC}"
echo -e "${PURPLE}====================${NC}"
echo

echo -e "${GREEN}=========================${NC}"
echo -e "${WHITE}1. Environment variables${NC}"
echo -e "${GREEN}=========================${NC}"
echo

# Interactive input for variables

echo -ne "${CYAN}Panel domain (e.g., example.com): ${NC}"
read PANEL_DOMAIN
while [[ -z "$PANEL_DOMAIN" ]] || ! validate_domain "$PANEL_DOMAIN"; do
    echo -e "${RED}Invalid domain! Please enter a valid domain (e.g., example.com)${NC}"
    echo -ne "${CYAN}Panel domain: ${NC}"
    read PANEL_DOMAIN
done

echo -ne "${CYAN}Sub domain (e.g., example.com): ${NC}"
read SUB_DOMAIN
while [[ -z "$SUB_DOMAIN" ]] || ! validate_domain "$SUB_DOMAIN"; do
    echo -e "${RED}Invalid domain! Please enter a valid domain${NC}"
    echo -ne "${CYAN}Sub domain: ${NC}"
    read SUB_DOMAIN
done

echo -ne "${CYAN}Self-steal domain (e.g., example.com): ${NC}"
read SELFSTEAL_DOMAIN
while [[ -z "$SELFSTEAL_DOMAIN" ]] || ! validate_domain "$SELFSTEAL_DOMAIN"; do
    echo -e "${RED}Invalid domain! Please enter a valid domain${NC}"
    echo -ne "${CYAN}Self-steal domain: ${NC}"
    read SELFSTEAL_DOMAIN
done

echo -ne "${CYAN}Cloudflare Email: ${NC}"
read CLOUDFLARE_EMAIL
while [[ -z "$CLOUDFLARE_EMAIL" ]]; do
    echo -e "${RED}Cloudflare Email cannot be empty!${NC}"
    echo -ne "${CYAN}Cloudflare Email: ${NC}"
    read CLOUDFLARE_EMAIL
done

echo -ne "${CYAN}Cloudflare API Key: ${NC}"
read CLOUDFLARE_API_KEY
while [[ -z "$CLOUDFLARE_API_KEY" ]]; do
    echo -e "${RED}Cloudflare API Key cannot be empty!${NC}"
    echo -ne "${CYAN}Cloudflare API Key: ${NC}"
    read CLOUDFLARE_API_KEY
done

echo -ne "${CYAN}Node public IP: ${NC}"
read NODE_PUBLIC_IP
while [[ -z "$NODE_PUBLIC_IP" ]] || ! validate_ip "$NODE_PUBLIC_IP"; do
    echo -e "${RED}Invalid IP! Please enter a valid IPv4 address (e.g., 1.2.3.4)${NC}"
    echo -ne "${CYAN}Node public IP: ${NC}"
    read NODE_PUBLIC_IP
done

echo
echo -e "${GREEN}Domains and Cloudflare credentials configured.${NC}"
echo -e "${GREEN}Node IP configured: $NODE_PUBLIC_IP${NC}"
echo

echo -e "${GREEN}------------------------------------${NC}"
echo -e "${GREEN}✓${NC} Environment variables configured!"
echo -e "${GREEN}------------------------------------${NC}"
echo

echo -e "${GREEN}=======================${NC}"
echo -e "${WHITE}2. Installing packages${NC}"
echo -e "${GREEN}=======================${NC}"
echo

# System upgrade and package installation
echo "Installing basic packages..."
apt-get update > /dev/null 2>&1
apt-get -y install jq curl unzip wget python3-certbot-dns-cloudflare > /dev/null 2>&1

# Setting the locale
echo "Configuring locales..."
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen 2>/dev/null
locale-gen > /dev/null 2>&1
update-locale LANG=en_US.UTF-8 > /dev/null 2>&1

# Time zone setting
echo "Setting timezone to Europe/Moscow..."
timedatectl set-timezone Europe/Moscow > /dev/null 2>&1

# Configuring TCP BBR
echo "Configuring TCP BBR..."
echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf 2>/dev/null
echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf 2>/dev/null
sysctl -p > /dev/null 2>&1

# Configuring automatic security updates
echo "Configuring unattended upgrades..."
apt-get -y install unattended-upgrades ufw > /dev/null 2>&1
echo 'Unattended-Upgrade::Mail "root";' >> /etc/apt/apt.conf.d/50unattended-upgrades 2>/dev/null
echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections > /dev/null 2>&1
dpkg-reconfigure -f noninteractive unattended-upgrades > /dev/null 2>&1
systemctl restart unattended-upgrades > /dev/null 2>&1

# Configuring UFW Firewall
echo "Configuring UFW firewall..."
ufw --force reset > /dev/null 2>&1
ufw allow 22/tcp comment 'SSH' > /dev/null 2>&1
ufw allow 443/tcp comment 'Marzban Dashboard' > /dev/null 2>&1
ufw allow 10000/tcp comment 'VLESS Reality' > /dev/null 2>&1

# Adding Node UFW Rules
echo "Configuring Marznode access for IP: $NODE_PUBLIC_IP"
ufw allow from "$NODE_PUBLIC_IP" to any port 62050 proto tcp comment 'Marznode' > /dev/null 2>&1
ufw allow from "$NODE_PUBLIC_IP" to any port 62051 proto tcp comment 'Marznode' > /dev/null 2>&1

ufw --force enable > /dev/null 2>&1
echo -e "${GREEN}UFW firewall configured successfully!${NC}"

# Docker Installation
if ! command -v docker >/dev/null 2>&1; then
    echo "Adding Docker repository..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | tee /etc/apt/keyrings/docker.asc > /dev/null
    chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    echo "Installing Docker..."
    apt-get update > /dev/null 2>&1
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1
    echo -e "${GREEN}Docker installed successfully${NC}"
fi

# Defining docker compose command
if docker compose version >/dev/null 2>&1; then
    COMPOSE='docker compose'
elif docker-compose version >/dev/null 2>&1; then
    COMPOSE='docker-compose'
else
    echo -e "${RED}docker compose not found${NC}"
    exit 1
fi

echo "Using: $COMPOSE"

# Architecture definition (Linux x86_64 and arm64 only)
case "$(uname -m)" in
    'amd64' | 'x86_64')
        ARCH='64'
        yq_binary="yq_linux_amd64"
        ;;
    'aarch64')
        ARCH='arm64-v8a'
        yq_binary="yq_linux_arm64"
        ;;
    *)
        echo -e "${RED}Unsupported architecture: $(uname -m)${NC}"
        echo -e "${RED}Supported: x86_64, aarch64${NC}"
        exit 1
        ;;
esac

echo "Detected architecture: $ARCH"

# YQ installation
if ! command -v yq &>/dev/null; then
    echo "Installing yq..."
    yq_url="https://github.com/mikefarah/yq/releases/latest/download/${yq_binary}"
    echo "Downloading yq from ${yq_url}..."
    
    curl -L "$yq_url" -o /usr/local/bin/yq > /dev/null 2>&1
    chmod +x /usr/local/bin/yq
    echo -e "${GREEN}yq installed successfully!${NC}"
    
    export PATH="/usr/local/bin:$PATH"
    hash -r
else
    echo "yq is already installed."
fi

echo
echo -e "${GREEN}----------------------------------${NC}"
echo -e "${GREEN}✓${NC} Package installation completed!"
echo -e "${GREEN}----------------------------------${NC}"
echo

# Path variables
INSTALL_DIR="/opt"
APP_NAME="marzban"
APP_DIR="$INSTALL_DIR/$APP_NAME"
DATA_DIR="/var/lib/$APP_NAME"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"
ENV_FILE="$APP_DIR/.env"

echo -e "${GREEN}=======================================${NC}"
echo -e "${WHITE}3. Creating structure and certificates${NC}"
echo -e "${GREEN}=======================================${NC}"
echo

echo "Creating directory structure..."
mkdir -p "$DATA_DIR"
mkdir -p "$APP_DIR"

echo "App directory: $APP_DIR"
echo "Data directory: $DATA_DIR"

# SSL Certificate Setup
# Check Cloudflare API
echo "Checking Cloudflare API..."
if [[ $CLOUDFLARE_API_KEY =~ [A-Z] ]]; then
    api_response=$(curl --silent --request GET --url https://api.cloudflare.com/client/v4/zones --header "Authorization: Bearer ${CLOUDFLARE_API_KEY}" --header "Content-Type: application/json")
else
    api_response=$(curl --silent --request GET --url https://api.cloudflare.com/client/v4/zones --header "X-Auth-Key: ${CLOUDFLARE_API_KEY}" --header "X-Auth-Email: ${CLOUDFLARE_EMAIL}" --header "Content-Type: application/json")
fi

# Generate certificates
echo "Setting up Cloudflare credentials..."
mkdir -p ~/.secrets/certbot

if [ ! -f ~/.secrets/certbot/cloudflare.ini ]; then
    echo "Creating Cloudflare credentials file..."
    if [[ $CLOUDFLARE_API_KEY =~ [A-Z] ]]; then
        cat > ~/.secrets/certbot/cloudflare.ini <<EOL
dns_cloudflare_api_token = $CLOUDFLARE_API_KEY
EOL
    else
        cat > ~/.secrets/certbot/cloudflare.ini <<EOL
dns_cloudflare_email = $CLOUDFLARE_EMAIL
dns_cloudflare_api_key = $CLOUDFLARE_API_KEY
EOL
    fi
    chmod 600 ~/.secrets/certbot/cloudflare.ini
    echo -e "${GREEN}Cloudflare credentials file created.${NC}"
else
    echo "Cloudflare credentials file already exists, skipping creation..."
fi

# Extract base domains
echo "Extracting base domains..."
PANEL_BASE_DOMAIN=$(echo "$PANEL_DOMAIN" | awk -F'.' '{if (NF > 2) {print $(NF-1)"."$NF} else {print $0}}')
SUB_BASE_DOMAIN=$(echo "$SUB_DOMAIN" | awk -F'.' '{if (NF > 2) {print $(NF-1)"."$NF} else {print $0}}')

# Generate certificate for panel domain if not exists
echo "Checking certificate for panel domain..."
if [ ! -d "/etc/letsencrypt/live/$PANEL_BASE_DOMAIN" ]; then
    echo "Generating certificate for $PANEL_BASE_DOMAIN..."
    certbot certonly \
        --dns-cloudflare \
        --dns-cloudflare-credentials ~/.secrets/certbot/cloudflare.ini \
        --dns-cloudflare-propagation-seconds 10 \
        -d "$PANEL_BASE_DOMAIN" \
        -d "*.$PANEL_BASE_DOMAIN" \
        --email "$CLOUDFLARE_EMAIL" \
        --agree-tos \
        --non-interactive \
        --key-type ecdsa \
        --elliptic-curve secp384r1
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to generate SSL certificate for $PANEL_BASE_DOMAIN. Check Cloudflare credentials.${NC}"
        exit 1
    fi
else
    echo "Certificate for $PANEL_BASE_DOMAIN already exists, skipping..."
fi

# Generate certificate for sub domain if not exists
echo "Checking certificate for sub domain..."
if [ ! -d "/etc/letsencrypt/live/$SUB_BASE_DOMAIN" ]; then
    echo "Generating certificate for $SUB_BASE_DOMAIN..."
    certbot certonly \
        --dns-cloudflare \
        --dns-cloudflare-credentials ~/.secrets/certbot/cloudflare.ini \
        --dns-cloudflare-propagation-seconds 10 \
        -d "$SUB_BASE_DOMAIN" \
        -d "*.$SUB_BASE_DOMAIN" \
        --email "$CLOUDFLARE_EMAIL" \
        --agree-tos \
        --non-interactive \
        --key-type ecdsa \
        --elliptic-curve secp384r1
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to generate SSL certificate for $SUB_BASE_DOMAIN. Check Cloudflare credentials.${NC}"
        exit 1
    fi
else
    echo "Certificate for $SUB_BASE_DOMAIN already exists, skipping..."
fi

# Configure renewal hooks and cron
echo "Configuring certificate renewal..."
if [ -f "/etc/letsencrypt/renewal/$PANEL_BASE_DOMAIN.conf" ]; then
    echo "renew_hook = systemctl restart marzban" >> /etc/letsencrypt/renewal/$PANEL_BASE_DOMAIN.conf
fi
if [ -f "/etc/letsencrypt/renewal/$SUB_BASE_DOMAIN.conf" ]; then
    echo "renew_hook = systemctl restart marzban" >> /etc/letsencrypt/renewal/$SUB_BASE_DOMAIN.conf
fi
(crontab -u root -l 2>/dev/null; echo "0 5 1 */2 * /usr/bin/certbot renew --quiet") | crontab -u root -

echo -e "${GREEN}SSL certificates configured successfully!${NC}"
echo

echo -e "${GREEN}----------------------------------------------${NC}"
echo -e "${GREEN}✓${NC} Structure and certificates setup completed!"
echo -e "${GREEN}----------------------------------------------${NC}"
echo

echo -e "${GREEN}====================================${NC}"
echo -e "${WHITE}4. Installing and configuring Nginx${NC}"
echo -e "${GREEN}====================================${NC}"
echo

# Nginx Installation and Configuration
echo "Installing Nginx from official repository..."
curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor --yes -o /etc/apt/keyrings/nginx-signing.gpg > /dev/null 2>&1
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/nginx-signing.gpg] http://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" > /etc/apt/sources.list.d/nginx.list
apt update > /dev/null 2>&1 && apt install nginx -y > /dev/null 2>&1

echo "Creating SSL snippets..."
# Create snippets directory if it doesn't exist
mkdir -p /etc/nginx/snippets

# Create SSL snippet for panel domain
cat > /etc/nginx/snippets/ssl.conf << EOF
ssl_certificate /etc/letsencrypt/live/$PANEL_BASE_DOMAIN/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/$PANEL_BASE_DOMAIN/privkey.pem;
EOF

# Create SSL snippet for subscription domain
cat > /etc/nginx/snippets/ssl-sub.conf << EOF
ssl_certificate /etc/letsencrypt/live/$SUB_BASE_DOMAIN/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/$SUB_BASE_DOMAIN/privkey.pem;
EOF

# Create SSL parameters snippet
cat > /etc/nginx/snippets/ssl-params.conf << 'EOF'
ssl_session_timeout 1d;
ssl_session_cache shared:MozSSL:10m;
ssl_session_tickets off;

resolver 8.8.8.8 8.8.4.4;
resolver_timeout 5s;

ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
ssl_prefer_server_ciphers off;
EOF

echo "Removing default Nginx configuration..."
rm -f /etc/nginx/conf.d/default.conf

echo "Creating Marzban dashboard configuration..."
cat > /etc/nginx/conf.d/marzban-dash.conf << EOF
server {
    server_name  dash.$PANEL_DOMAIN;

    listen       443 ssl;
    http2        on;

    location ~* /(sub|dashboard|api|statics|docs|redoc|openapi.json) {
        proxy_redirect          off;
        proxy_http_version      1.1;
        proxy_pass              http://127.0.0.1:8000;
        proxy_set_header        Upgrade \$http_upgrade;
        proxy_set_header        Connection "upgrade";
        proxy_set_header        Host \$host;
        proxy_set_header        X-Real-IP \$remote_addr;
        proxy_set_header        X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto \$scheme;
    }

    location / {
        return 404;
    }

    include      /etc/nginx/snippets/ssl.conf;
    include      /etc/nginx/snippets/ssl-params.conf;
}
EOF

echo "Creating subscription site configuration..."
cat > /etc/nginx/conf.d/sub-site.conf << EOF
server {
    server_name  $SUB_DOMAIN;

    listen       443 ssl;
    http2        on;

    location /sub {
        proxy_redirect          off;
        proxy_http_version      1.1;
        proxy_pass              http://127.0.0.1:8000;
        proxy_set_header        Host \$host;
        proxy_set_header        X-Real-IP \$remote_addr;
        proxy_set_header        X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto \$scheme;
    }

    location / {
        return 401;
    }

    include      /etc/nginx/snippets/ssl-sub.conf;
    include      /etc/nginx/snippets/ssl-params.conf;
}
EOF

echo "Creating main Nginx configuration..."
cat > /etc/nginx/nginx.conf << 'EOF'
user  nginx;
worker_processes  auto;
error_log  /var/log/nginx/error.log notice;
pid        /run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    gzip on;
    gzip_disable "msie6";

    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_min_length 256;
    gzip_types
      application/atom+xml
      application/geo+json
      application/javascript
      application/x-javascript
      application/json
      application/ld+json
      application/manifest+json
      application/rdf+xml
      application/rss+xml
      application/xhtml+xml
      application/xml
      font/eot
      font/otf
      font/ttf
      image/svg+xml
      text/css
      text/javascript
      text/plain
      text/xml;

    resolver 8.8.8.8 8.8.4.4;

    include /etc/nginx/conf.d/*.conf;
}
EOF

echo "Testing Nginx configuration and starting service..."
nginx -t && systemctl restart nginx && systemctl enable nginx > /dev/null 2>&1

echo -e "${GREEN}Nginx configured successfully!${NC}"
echo

echo -e "${GREEN}---------------------------------------------${NC}"
echo -e "${GREEN}✓${NC} Nginx configured and started successfully!"
echo -e "${GREEN}---------------------------------------------${NC}"
echo

echo -e "${GREEN}================================${NC}"
echo -e "${WHITE}5. Creating configuration files${NC}"
echo -e "${GREEN}================================${NC}"
echo

echo "Setting up docker-compose.yml for MariaDB"

# Creating docker-compose.yml with MariaDB
cat > "$APP_DIR/docker-compose.yml" <<'EOF'
services:
  marzban:
    image: gozargah/marzban:latest
    restart: always
    env_file: .env
    network_mode: host
    volumes:
      - /var/lib/marzban:/var/lib/marzban
      - /var/lib/marzban/logs:/var/lib/marzban-node
      - /var/lib/marzban/subscription.py:/code/app/routers/subscription.py
    depends_on:
      mariadb:
        condition: service_healthy

  mariadb:
    image: mariadb:lts
    env_file: .env
    network_mode: host
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_ROOT_HOST: '%'
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    command:
      - --bind-address=127.0.0.1
      - --character_set_server=utf8mb4
      - --collation_server=utf8mb4_unicode_ci
      - --host-cache-size=0
      - --innodb-open-files=1024
      - --innodb-buffer-pool-size=256M
      - --binlog_expire_logs_seconds=1209600
      - --innodb-log-file-size=64M
      - --innodb-log-files-in-group=2
      - --innodb-doublewrite=0
      - --general_log=0
      - --slow_query_log=1
      - --slow_query_log_file=/var/lib/mysql/slow.log
      - --long_query_time=2
    volumes:
      - /var/lib/marzban/mysql:/var/lib/mysql
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      start_period: 10s
      start_interval: 3s
      interval: 10s
      timeout: 5s
      retries: 3
EOF

echo -e "${GREEN}Using MariaDB as database${NC}"
echo "File generated at $APP_DIR/docker-compose.yml"

echo "Creating .env configuration file"

# Data generation
echo -e "${YELLOW}Generating secure random values...${NC}"
MYSQL_ROOT_PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20)
MYSQL_PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20)
WEBHOOK_SECRET=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)
ADMIN_USERNAME=$(tr -dc 'a-zA-Z' </dev/urandom | head -c 8)
ADMIN_PASSWORD=$(tr -dc 'A-Za-z0-9!@#%^&*()' </dev/urandom | head -c 16)

# Creating an .env file with passwords
cat > "$APP_DIR/.env" << EOF
UVICORN_HOST = "0.0.0.0"
UVICORN_PORT = 8000
# ALLOWED_ORIGINS=http://localhost,http://localhost:8000,http://example.com

## We highly recommend add admin using \`marzban cli\` tool and do not use
## the following variables which is somehow hard codded infrmation.
# SUDO_USERNAME = "admin"
# SUDO_PASSWORD = "admin"

# UVICORN_UDS: "/run/marzban.socket"
# UVICORN_SSL_CERTFILE = "/var/lib/marzban/certs/example.com/fullchain.pem"
# UVICORN_SSL_KEYFILE = "/var/lib/marzban/certs/example.com/key.pem"
# UVICORN_SSL_CA_TYPE = "public"

# DASHBOARD_PATH = "/dashboard/"

XRAY_JSON = "/var/lib/marzban/xray_config.json"
XRAY_SUBSCRIPTION_URL_PREFIX = "https://$SUB_DOMAIN"
# XRAY_SUBSCRIPTION_PATH = "sub"
XRAY_EXECUTABLE_PATH = "/usr/local/bin/xray"
# XRAY_ASSETS_PATH = "/usr/local/share/xray"
# XRAY_EXCLUDE_INBOUND_TAGS = "INBOUND_X INBOUND_Y"
# XRAY_FALLBACKS_INBOUND_TAG = "INBOUND_X"


# TELEGRAM_API_TOKEN = 123456789:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# TELEGRAM_ADMIN_ID = 987654321, 123456789
# TELEGRAM_LOGGER_CHANNEL_ID = -1234567890123
# TELEGRAM_DEFAULT_VLESS_FLOW = "xtls-rprx-vision"
# TELEGRAM_PROXY_URL = "http://localhost:8080"

# DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/xxxxxxx"

CUSTOM_TEMPLATES_DIRECTORY="/var/lib/marzban/templates/"
# CLASH_SUBSCRIPTION_TEMPLATE="clash/my-custom-template.yml"
SUBSCRIPTION_PAGE_TEMPLATE="subscription/index.html"
# HOME_PAGE_TEMPLATE="home/index.html"

# V2RAY_SUBSCRIPTION_TEMPLATE="v2ray/default.json"
# V2RAY_SETTINGS_TEMPLATE="v2ray/settings.json"

# SINGBOX_SUBSCRIPTION_TEMPLATE="singbox/default.json"
# SINGBOX_SETTINGS_TEMPLATE="singbox/settings.json"

# MUX_TEMPLATE="mux/default.json"

## Enable JSON config for compatible clients to use mux, fragment, etc. Default False.
# USE_CUSTOM_JSON_DEFAULT=True
## Your preferred config type for different clients
## If USE_CUSTOM_JSON_DEFAULT is set True, all following programs will use the JSON config
# USE_CUSTOM_JSON_FOR_V2RAYN=False
# USE_CUSTOM_JSON_FOR_V2RAYNG=True
# USE_CUSTOM_JSON_FOR_STREISAND=False
USE_CUSTOM_JSON_FOR_HAPP=True

## Set headers for subscription
# SUB_PROFILE_TITLE = "Susbcription"
# SUB_SUPPORT_URL = "https://t.me/support"
SUB_UPDATE_INTERVAL = "1"

## External config to import into v2ray format subscription
# EXTERNAL_CONFIG = "config://..."

# SQLALCHEMY_DATABASE_URL = "sqlite:///db.sqlite3"
# SQLALCHEMY_POOL_SIZE = 10
# SQLIALCHEMY_MAX_OVERFLOW = 30

## Custom text for STATUS_TEXT variable
# ACTIVE_STATUS_TEXT = "Active"
# EXPIRED_STATUS_TEXT = "Expired"
# LIMITED_STATUS_TEXT = "Limited"
# DISABLED_STATUS_TEXT = "Disabled"
# ONHOLD_STATUS_TEXT = "On-Hold"

### Use negative values to disable auto-delete by default
# USERS_AUTODELETE_DAYS = -1
# USER_AUTODELETE_INCLUDE_LIMITED_ACCOUNTS = false

## Customize all notifications
# NOTIFY_STATUS_CHANGE = True
# NOTIFY_USER_CREATED = True
# NOTIFY_USER_UPDATED = True
# NOTIFY_USER_DELETED = True
# NOTIFY_USER_DATA_USED_RESET = True
# NOTIFY_USER_SUB_REVOKED = True
# NOTIFY_IF_DATA_USAGE_PERCENT_REACHED = True
# NOTIFY_IF_DAYS_LEFT_REACHED = True
# NOTIFY_LOGIN = True

## Whitelist of IPs/hosts to disable login notifications
# LOGIN_NOTIFY_WHITE_LIST = '1.1.1.1,127.0.0.1'

### for developers
# DOCS=True
# DEBUG=True

# If You Want To Send Webhook To Multiple Server Add Multi Address
WEBHOOK_ADDRESS = "http://127.0.0.1:8777/notify_user"
WEBHOOK_SECRET = "$WEBHOOK_SECRET"
NOTIFY_DAYS_LEFT=1
NOTIFY_REACHED_USAGE_PERCENT=90

# VITE_BASE_API="https://example.com/api/"
# JWT_ACCESS_TOKEN_EXPIRE_MINUTES = 1440

# JOB_CORE_HEALTH_CHECK_INTERVAL = 10
# JOB_RECORD_NODE_USAGES_INTERVAL = 30
# JOB_RECORD_USER_USAGES_INTERVAL = 10
# JOB_REVIEW_USERS_INTERVAL = 10
# JOB_SEND_NOTIFICATIONS_INTERVAL = 30

# Database configuration
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=marzban
MYSQL_USER=marzban
MYSQL_PASSWORD=$MYSQL_PASSWORD

# SQLAlchemy Database URL
SQLALCHEMY_DATABASE_URL="mysql+pymysql://marzban:${MYSQL_PASSWORD}@127.0.0.1:3306/marzban"
EOF

echo -e "${GREEN}.env file created with database configuration${NC}"

# Setting secure access rights
echo "Setting secure permissions on configuration files..."
chmod 600 "$APP_DIR/.env"
chown root:root "$APP_DIR/.env"

echo "Creating custom xray config file"
echo "Generating VLESS Reality configuration..."

# Generate VLESS Reality parameters using system tools
VLESS_UUID=$(cat /proc/sys/kernel/random/uuid)
PRIVATE_KEY=$(openssl genpkey -algorithm X25519 2>/dev/null | openssl pkey -outform DER 2>/dev/null | tail -c +17 | head -c 32 | base64 | tr '/+' '_-' | tr -d '=')
SHORT_ID=$(openssl rand -hex 4)

cat > "$DATA_DIR/xray_config.json" << EOF
{
  "log": {
    "access": "/var/lib/marzban-node/access.log",
    "error": "/var/lib/marzban-node/error.log",
    "loglevel": "debug",
    "dnsLog": true
  },
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "ip": ["geoip:private"],
        "outboundTag": "BLOCK",
        "type": "field"
      },
      {
        "type": "field",
        "outboundTag": "IPv4",
        "domain": ["geosite:google"]
      },
      {
        "protocol": ["bittorrent"],
        "outboundTag": "BLOCK",
        "type": "field"
      }
    ]
  },
  "inbounds": [
    {
      "tag": "VLESS Reality Steal Oneself",
      "listen": "0.0.0.0",
      "port": 10000,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$VLESS_UUID",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "$SELFSTEAL_DOMAIN:443",
          "serverNames": [
            "$PANEL_DOMAIN"
          ],
          "privateKey": "$PRIVATE_KEY",
          "shortIds": [
            "$SHORT_ID"
          ],
          "fingerprint": "chrome"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "DIRECT"
    },
    {
      "protocol": "blackhole",
      "tag": "BLOCK"
    },
    {
      "tag": "IPv4",
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "ForceIPv4"
      }
    }
  ]
}
EOF
echo -e "${GREEN}Custom xray config created at $DATA_DIR/xray_config.json${NC}"

echo "Downloading custom subscription template..."
mkdir -p /var/lib/marzban/templates/subscription
wget -q https://raw.githubusercontent.com/supermegaelf/mb-files/main/pages/sub/index.html -O /var/lib/marzban/templates/subscription/index.html > /dev/null 2>&1

# Replacing example.com with actual panel domain
sed -i "s/example\.com/$PANEL_DOMAIN/g" /var/lib/marzban/templates/subscription/index.html

echo -e "${GREEN}Custom subscription template configured at /var/lib/marzban/templates/subscription/index.html${NC}"

echo "Downloading enhanced subscription router..."
wget -O /var/lib/marzban/subscription.py "https://raw.githubusercontent.com/hydraponique/roscomvpn-happ-routing/main/Auto-routing%20for%20Non-json%20Marzban/subscription.py" > /dev/null 2>&1
echo -e "${GREEN}Enhanced subscription router downloaded to /var/lib/marzban/subscription.py${NC}"

echo -e "${GREEN}Marzban's files downloaded successfully${NC}"

echo "Installing marzban script"
FETCH_REPO="Gozargah/Marzban-scripts"
SCRIPT_URL="https://github.com/$FETCH_REPO/raw/master/marzban.sh"
curl -sSL $SCRIPT_URL | install -m 755 /dev/stdin /usr/local/bin/marzban
echo -e "${GREEN}marzban script installed successfully${NC}"

echo
echo -e "${GREEN}--------------------------------------------${NC}"
echo -e "${GREEN}✓${NC} Configuration files created successfully!"
echo -e "${GREEN}--------------------------------------------${NC}"
echo

echo -e "${GREEN}========================================${NC}"
echo -e "${WHITE}6. Downloading and installing Xray-core${NC}"
echo -e "${GREEN}========================================${NC}"
echo

# Creating and navigating to a directory
mkdir -p /tmp/xray-install
cd /tmp/xray-install

# Getting a list of the latest versions
LAST_XRAY_CORES=10
latest_releases=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases?per_page=$LAST_XRAY_CORES")
latest_version=$(echo "$latest_releases" | grep -oP '"tag_name": "\K(.*?)(?=")' | head -n 1)

echo "Latest Xray-core version: $latest_version"

# File name and URL generation
xray_filename="Xray-linux-$ARCH.zip"
xray_download_url="https://github.com/XTLS/Xray-core/releases/download/${latest_version}/${xray_filename}"

echo "Downloading Xray-core version ${latest_version}..."
wget -q -O "${xray_filename}" "${xray_download_url}"

echo "Extracting Xray-core..."
unzip -o "${xray_filename}" >/dev/null 2>&1

# Installation in the default path
echo "Installing Xray to /usr/local/bin/..."
cp xray /usr/local/bin/
chmod +x /usr/local/bin/xray

# Clearing temporary files
cd /
rm -rf /tmp/xray-install

echo -e "${GREEN}Xray-core installed successfully to /usr/local/bin/xray${NC}"

echo
echo -e "${GREEN}------------------------------------${NC}"
echo -e "${GREEN}✓${NC} Xray-core installation completed!"
echo -e "${GREEN}------------------------------------${NC}"
echo

echo -e "${GREEN}==============================${NC}"
echo -e "${WHITE}7. Starting Docker containers${NC}"
echo -e "${GREEN}==============================${NC}"
echo

# Adding the path to Xray to the .env file
echo "Starting Docker containers..."
cd "$APP_DIR"

# Launching containers
$COMPOSE up -d --remove-orphans
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to start containers. Check: $COMPOSE logs${NC}"
    exit 1
fi

echo "Containers started. Waiting for services to be ready..."
sleep 30
if ! curl -s "http://localhost:8000" > /dev/null; then
    echo -e "${RED}❌ Marzban not responding. Check: $COMPOSE logs marzban${NC}"
    exit 1
fi

echo "Checking container status..."
$COMPOSE ps

echo -e "${GREEN}=======================${NC}"
echo -e "${WHITE}8. Creating admin user${NC}"
echo -e "${GREEN}=======================${NC}"
echo

# Install python3-bcrypt if not available
if ! python3 -c "import bcrypt" 2>/dev/null; then
    echo "Installing python3-bcrypt..."
    apt-get update > /dev/null 2>&1
    apt-get -y install python3-bcrypt > /dev/null 2>&1
fi

# Generate random password
ADMIN_PASSWORD=$(tr -dc 'A-Za-z0-9!@#%^&*()' </dev/urandom | head -c 16)

echo "Creating admin user via database..."

# Generate bcrypt password hash
ADMIN_PASSWORD_HASH=$(python3 -c "import bcrypt; print(bcrypt.hashpw('$ADMIN_PASSWORD'.encode(), bcrypt.gensalt()).decode())")

# Get MySQL password from .env file
MYSQL_PASSWORD=$(grep "^MYSQL_PASSWORD=" "$APP_DIR/.env" | cut -d'=' -f2)

# Find MariaDB container
container_id=$(docker ps -q -f ancestor=mariadb:lts)

if [ -n "$container_id" ]; then
    # Create admin via SQL
    docker exec $container_id mariadb -u marzban -p"$MYSQL_PASSWORD" marzban -e "
    INSERT INTO admins (username, hashed_password, is_sudo, created_at) 
    VALUES ('admin', '$ADMIN_PASSWORD_HASH', 1, NOW())
    ON DUPLICATE KEY UPDATE 
        hashed_password = '$ADMIN_PASSWORD_HASH',
        is_sudo = 1;
    " 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Admin user created successfully via database!${NC}"
    else
        echo -e "${YELLOW}⚠ Admin may already exist, trying to update password...${NC}"
    fi
else
    echo -e "${RED}❌ Cannot find MariaDB container${NC}"
fi

echo
echo -e "${CYAN}Updating hosts configuration via API...${NC}"

# Wait a bit to ensure admin is created
sleep 5

# Get authentication token
echo "Getting authentication token..."
TOKEN_RESPONSE=$(curl -s -X POST "https://dash.$PANEL_DOMAIN/api/admin/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin&password=$ADMIN_PASSWORD")

TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ "$TOKEN" != "null" ] && [ -n "$TOKEN" ]; then
    echo "✓ Authentication successful"
    
    # Update hosts via API
    echo "Updating hosts configuration..."
    HOSTS_RESPONSE=$(curl -s -X PUT "https://dash.$PANEL_DOMAIN/api/hosts" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d '{
        "VLESS Reality Steal Oneself": [{
          "remark": "Steal",
          "address": "'$SELFSTEAL_DOMAIN'",
          "port": 443,
          "sni": "'$PANEL_DOMAIN'",
          "fingerprint": "chrome",
          "security": "inbound_default",
          "alpn": "",
          "allowinsecure": null,
          "is_disabled": false,
          "mux_enable": false,
          "fragment_setting": null,
          "noise_setting": null,
          "random_user_agent": false,
          "use_sni_as_host": false
        }]
      }')
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Hosts configuration updated successfully via API!${NC}"
    else
        echo -e "${YELLOW}⚠ Could not update hosts via API${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Could not get authentication token. You can update hosts manually through the dashboard.${NC}"
fi

echo
echo -e "${GREEN}------------------------------------------${NC}"
echo -e "${GREEN}✓${NC} Docker containers started successfully!"
echo -e "${GREEN}------------------------------------------${NC}"
echo

echo -e "${GREEN}----------------------------------------${NC}"
echo -e "${GREEN}✓${NC} Marzban setup completed successfully!"
echo -e "${GREEN}----------------------------------------${NC}"
echo
echo -e "${CYAN}Dashboard URL:${NC}"
echo -e "${WHITE}https://dash.$PANEL_DOMAIN/dashboard${NC}"
echo
echo -e "${CYAN}Credentials:${NC}"
echo -e "${WHITE}admin${NC}"
echo -e "${WHITE}$ADMIN_PASSWORD${NC}"
echo
echo -e "${CYAN}Check logs with:${NC}"
echo -e "${WHITE}marzban logs${NC}"
echo
echo -e "${YELLOW}To complete the setup:${NC}"
echo -e "${WHITE}1. Go to "Node settings" in the Marzban panel.${NC}"
echo -e "${WHITE}2. Fill in the "Name" and "Address" fields.${NC}"
echo -e "${WHITE}3. Click "Update Node".${NC}"
echo
echo -e "${CYAN}To prepare the node installation:${NC}"
echo -e "${WHITE}1. Go to "Node settings" in the Marzban panel.${NC}"
echo -e "${WHITE}2. Click "Add New Marzban Node".${NC}"
echo -e "${WHITE}3. Click "Show Certificate" and copy it to the clipboard.${NC}"
echo -e "${WHITE}4. Run the script on the node server and select "Install Node".${NC}"
echo

# Node Installation

elif [ "$INSTALL_TYPE" = "2" ]; then

# Marzban Node setup

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Checking root permissions
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}This command must be run as root.${NC}"
    exit 1
fi

# Domain validation
validate_domain() {
    local domain=$1
    if [[ "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] && [[ ! "$domain" =~ [[:space:]] ]]; then
        return 0
    fi
    return 1
}

# IPv4 validation
validate_ip() {
    local ip=$1
    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        return 0
    fi
    return 1
}

# Command execution check
check_command() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Error: $1${NC}"
        exit 1
    fi
}

echo
echo -e "${PURPLE}===================${NC}"
echo -e "${WHITE}MARZBAN NODE SETUP${NC}"
echo -e "${PURPLE}===================${NC}"
echo

echo -e "${GREEN}=========================${NC}"
echo -e "${WHITE}1. Environment variables${NC}"
echo -e "${GREEN}=========================${NC}"
echo

# Interactive input for variables
echo -ne "${CYAN}Selfsteal domain (e.g., example.com): ${NC}"
read SELFSTEAL_DOMAIN
while [[ -z "$SELFSTEAL_DOMAIN" ]] || ! validate_domain "$SELFSTEAL_DOMAIN"; do
    echo -e "${RED}Invalid domain! Please enter a valid domain (e.g., example.com)${NC}"
    echo -ne "${CYAN}Selfsteal domain: ${NC}"
    read SELFSTEAL_DOMAIN
done

echo -ne "${CYAN}Cloudflare Email: ${NC}"
read CLOUDFLARE_EMAIL
while [[ -z "$CLOUDFLARE_EMAIL" ]]; do
    echo -e "${RED}Cloudflare Email cannot be empty!${NC}"
    echo -ne "${CYAN}Cloudflare Email: ${NC}"
    read CLOUDFLARE_EMAIL
done

echo -ne "${CYAN}Cloudflare API Key: ${NC}"
read CLOUDFLARE_API_KEY
while [[ -z "$CLOUDFLARE_API_KEY" ]]; do
    echo -e "${RED}Cloudflare API Key cannot be empty!${NC}"
    echo -ne "${CYAN}Cloudflare API Key: ${NC}"
    read CLOUDFLARE_API_KEY
done

echo -ne "${CYAN}Main public IP: ${NC}"
read MAIN_PUBLIC_IP
while [[ -z "$MAIN_PUBLIC_IP" ]] || ! validate_ip "$MAIN_PUBLIC_IP"; do
    echo -e "${RED}Invalid IP! Please enter a valid IPv4 address (e.g., 1.2.3.4)${NC}"
    echo -ne "${CYAN}Main public IP: ${NC}"
    read MAIN_PUBLIC_IP
done

echo
echo -e "${GREEN}Domain and Cloudflare credentials configured.${NC}"
echo -e "${GREEN}Main IP configured: $MAIN_PUBLIC_IP${NC}"
echo

echo -e "${GREEN}------------------------------------${NC}"
echo -e "${GREEN}✓${NC} Environment variables configured!"
echo -e "${GREEN}------------------------------------${NC}"
echo

echo -e "${GREEN}=======================${NC}"
echo -e "${WHITE}2. Installing packages${NC}"
echo -e "${GREEN}=======================${NC}"
echo

# System upgrade and package installation
echo "Installing basic packages..."
apt-get update > /dev/null 2>&1
apt-get -y install jq curl unzip wget python3-certbot-dns-cloudflare git > /dev/null 2>&1

# Setting the locale
echo "Configuring locales..."
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen 2>/dev/null
locale-gen > /dev/null 2>&1
update-locale LANG=en_US.UTF-8 > /dev/null 2>&1

# Time zone setting
echo "Setting timezone to Europe/Moscow..."
timedatectl set-timezone Europe/Moscow > /dev/null 2>&1

# Configuring TCP BBR
echo "Configuring TCP BBR..."
echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf 2>/dev/null
echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf 2>/dev/null
sysctl -p > /dev/null 2>&1

# Configuring automatic security updates
echo "Configuring unattended upgrades..."
apt-get -y install unattended-upgrades ufw > /dev/null 2>&1
echo 'Unattended-Upgrade::Mail "root";' >> /etc/apt/apt.conf.d/50unattended-upgrades 2>/dev/null
echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections > /dev/null 2>&1
dpkg-reconfigure -f noninteractive unattended-upgrades > /dev/null 2>&1
systemctl restart unattended-upgrades > /dev/null 2>&1

# Configuring UFW Firewall
echo "Configuring UFW firewall..."
ufw --force reset > /dev/null 2>&1
ufw allow 22/tcp comment 'SSH' > /dev/null 2>&1
ufw allow 443/tcp comment 'HTTPS (Reality)' > /dev/null 2>&1
ufw allow 10000/tcp comment 'HTTPS (Reality)' > /dev/null 2>&1

# Adding Main server UFW Rules
echo "Configuring main server access for IP: $MAIN_PUBLIC_IP"
ufw allow from "$MAIN_PUBLIC_IP" to any port 62050 proto tcp comment 'Marzmain' > /dev/null 2>&1
ufw allow from "$MAIN_PUBLIC_IP" to any port 62051 proto tcp comment 'Marzmain' > /dev/null 2>&1

ufw --force enable > /dev/null 2>&1
echo -e "${GREEN}UFW firewall configured successfully!${NC}"

# Docker Installation
if ! command -v docker >/dev/null 2>&1; then
    echo "Adding Docker repository..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | tee /etc/apt/keyrings/docker.asc > /dev/null
    chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    echo "Installing Docker..."
    apt-get update > /dev/null 2>&1
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1
    echo -e "${GREEN}Docker installed successfully${NC}"
fi

# Defining docker compose command
if docker compose version >/dev/null 2>&1; then
    COMPOSE='docker compose'
elif docker-compose version >/dev/null 2>&1; then
    COMPOSE='docker-compose'
else
    echo -e "${RED}docker compose not found${NC}"
    exit 1
fi

echo "Using: $COMPOSE"

echo
echo -e "${GREEN}----------------------------------${NC}"
echo -e "${GREEN}✓${NC} Package installation completed!"
echo -e "${GREEN}----------------------------------${NC}"
echo

# Path variables
INSTALL_DIR="/opt"
APP_NAME="marzban-node"
APP_DIR="$INSTALL_DIR/$APP_NAME"
DATA_DIR="/var/lib/$APP_NAME"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"

echo -e "${GREEN}=======================================${NC}"
echo -e "${WHITE}3. Creating structure and certificates${NC}"
echo -e "${GREEN}=======================================${NC}"
echo

echo "Creating directory structure..."
mkdir -p "$DATA_DIR"
mkdir -p "$APP_DIR"
mkdir -p /var/lib/marzban

echo "App directory: $APP_DIR"
echo "Data directory: $DATA_DIR"

# SSL Certificate Setup
# Check Cloudflare API
echo "Checking Cloudflare API..."
if [[ $CLOUDFLARE_API_KEY =~ [A-Z] ]]; then
    api_response=$(curl --silent --request GET --url https://api.cloudflare.com/client/v4/zones --header "Authorization: Bearer ${CLOUDFLARE_API_KEY}" --header "Content-Type: application/json")
else
    api_response=$(curl --silent --request GET --url https://api.cloudflare.com/client/v4/zones --header "X-Auth-Key: ${CLOUDFLARE_API_KEY}" --header "X-Auth-Email: ${CLOUDFLARE_EMAIL}" --header "Content-Type: application/json")
fi

# Generate certificates
echo "Setting up Cloudflare credentials..."
mkdir -p ~/.secrets/certbot

if [ ! -f ~/.secrets/certbot/cloudflare.ini ]; then
    echo "Creating Cloudflare credentials file..."
    if [[ $CLOUDFLARE_API_KEY =~ [A-Z] ]]; then
        cat > ~/.secrets/certbot/cloudflare.ini <<EOL
dns_cloudflare_api_token = $CLOUDFLARE_API_KEY
EOL
    else
        cat > ~/.secrets/certbot/cloudflare.ini <<EOL
dns_cloudflare_email = $CLOUDFLARE_EMAIL
dns_cloudflare_api_key = $CLOUDFLARE_API_KEY
EOL
    fi
    chmod 600 ~/.secrets/certbot/cloudflare.ini
    echo -e "${GREEN}Cloudflare credentials file created.${NC}"
else
    echo "Cloudflare credentials file already exists, skipping creation..."
fi

# Extract base domain
echo "Extracting base domain..."
BASE_DOMAIN=$(echo "$SELFSTEAL_DOMAIN" | awk -F'.' '{if (NF > 2) {print $(NF-1)"."$NF} else {print $0}}')

# Generate wildcard certificate for selfsteal domain
echo "Checking certificate for selfsteal domain..."
if [ ! -d "/etc/letsencrypt/live/$BASE_DOMAIN" ]; then
    echo "Generating wildcard certificate for $BASE_DOMAIN..."
    certbot certonly \
        --dns-cloudflare \
        --dns-cloudflare-credentials ~/.secrets/certbot/cloudflare.ini \
        --dns-cloudflare-propagation-seconds 10 \
        -d "$BASE_DOMAIN" \
        -d "*.$BASE_DOMAIN" \
        --email "$CLOUDFLARE_EMAIL" \
        --agree-tos \
        --non-interactive \
        --key-type ecdsa \
        --elliptic-curve secp384r1
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to generate SSL certificate for $BASE_DOMAIN. Check Cloudflare credentials.${NC}"
        exit 1
    fi
else
    echo "Certificate for $BASE_DOMAIN already exists, skipping..."
fi

# Configure renewal hooks and cron
echo "Configuring certificate renewal..."
if [ -f "/etc/letsencrypt/renewal/$BASE_DOMAIN.conf" ]; then
    echo "renew_hook = systemctl reload nginx" >> /etc/letsencrypt/renewal/$BASE_DOMAIN.conf
fi
(crontab -u root -l 2>/dev/null; echo "0 5 1 */2 * /usr/bin/certbot renew --quiet") | crontab -u root -

echo -e "${GREEN}SSL certificates configured successfully!${NC}"
echo

echo -e "${GREEN}----------------------------------------------${NC}"
echo -e "${GREEN}✓${NC} Structure and certificates setup completed!"
echo -e "${GREEN}----------------------------------------------${NC}"
echo

echo -e "${GREEN}====================================${NC}"
echo -e "${WHITE}4. Installing and configuring Nginx${NC}"
echo -e "${GREEN}====================================${NC}"
echo

# Nginx Installation and Configuration
echo "Installing Nginx from official repository..."
curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor --yes -o /etc/apt/keyrings/nginx-signing.gpg > /dev/null 2>&1
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/nginx-signing.gpg] http://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" > /etc/apt/sources.list.d/nginx.list
apt update > /dev/null 2>&1 && apt install nginx -y > /dev/null 2>&1

echo "Creating SSL snippets..."
# Create snippets directory if it doesn't exist
mkdir -p /etc/nginx/snippets

# Create SSL snippet for selfsteal domain
cat > /etc/nginx/snippets/ssl.conf << EOF
ssl_certificate /etc/letsencrypt/live/$BASE_DOMAIN/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/$BASE_DOMAIN/privkey.pem;
EOF

# Create SSL parameters snippet
cat > /etc/nginx/snippets/ssl-params.conf << 'EOF'
ssl_session_timeout 1d;
ssl_session_cache shared:MozSSL:10m;
ssl_session_tickets off;

resolver 8.8.8.8 8.8.4.4;
resolver_timeout 5s;

ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
ssl_prefer_server_ciphers off;
EOF

echo "Removing default Nginx configuration..."
rm -f /etc/nginx/conf.d/default.conf

echo "Creating SNI site configuration..."
cat > /etc/nginx/conf.d/sni-site.conf << EOF
server {
    server_name $SELFSTEAL_DOMAIN;

    listen 443 ssl;
    http2 on;

    gzip on;

    location / {
        root /usr/share/nginx/html;
        index sni.html;
    }

    include /etc/nginx/snippets/ssl.conf;
    include /etc/nginx/snippets/ssl-params.conf;
}
EOF

echo "Downloading SNI page..."
wget -q https://raw.githubusercontent.com/supermegaelf/mb-files/main/pages/sni/sni.html -O /usr/share/nginx/html/sni.html > /dev/null 2>&1

echo "Creating main Nginx configuration..."
cat > /etc/nginx/nginx.conf << 'EOF'
user  nginx;
worker_processes  auto;
error_log  /var/log/nginx/error.log notice;
pid        /run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    gzip on;
    gzip_disable "msie6";

    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_min_length 256;
    gzip_types
      application/atom+xml
      application/geo+json
      application/javascript
      application/x-javascript
      application/json
      application/ld+json
      application/manifest+json
      application/rdf+xml
      application/rss+xml
      application/xhtml+xml
      application/xml
      font/eot
      font/otf
      font/ttf
      image/svg+xml
      text/css
      text/javascript
      text/plain
      text/xml;

    resolver 8.8.8.8 8.8.4.4;

    include /etc/nginx/conf.d/*.conf;
}
EOF

echo "Testing Nginx configuration and starting service..."
nginx -t && systemctl restart nginx && systemctl enable nginx > /dev/null 2>&1

echo -e "${GREEN}Nginx configured successfully!${NC}"
echo

echo -e "${GREEN}---------------------------------------------${NC}"
echo -e "${GREEN}✓${NC} Nginx configured and started successfully!"
echo -e "${GREEN}---------------------------------------------${NC}"
echo

echo -e "${GREEN}==========================================${NC}"
echo -e "${WHITE}5. Configuring traffic forwarding and UFW${NC}"
echo -e "${GREEN}==========================================${NC}"
echo

# Enable IP forwarding
echo "Enabling IP forwarding..."
echo 'net/ipv4/ip_forward=1' >> /etc/ufw/sysctl.conf

# Configure NAT rules for traffic forwarding
echo "Configuring NAT rules..."
cat >> /etc/ufw/before.rules << 'EOF'
*nat
:PREROUTING ACCEPT [0:0]
-A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 10000
COMMIT
EOF

echo "Reloading UFW with new NAT rules..."
ufw --force reload

echo -e "${GREEN}Traffic forwarding configured successfully!${NC}"
echo

echo -e "${GREEN}----------------------------------------------${NC}"
echo -e "${GREEN}✓${NC} Traffic forwarding and UFW setup completed!"
echo -e "${GREEN}----------------------------------------------${NC}"
echo

echo -e "${GREEN}================================${NC}"
echo -e "${WHITE}6. Creating configuration files${NC}"
echo -e "${GREEN}================================${NC}"
echo

echo "Setting up docker-compose.yml for Marzban Node"

# Creating docker-compose.yml
cat > "$APP_DIR/docker-compose.yml" <<'EOF'
services:
  marzban-node:
    image: gozargah/marzban-node:latest
    restart: always
    network_mode: host

    volumes:
      - /var/lib/marzban-node:/var/lib/marzban-node
      - /var/lib/marzban:/var/lib/marzban

    environment:
      SSL_CLIENT_CERT_FILE: "/var/lib/marzban-node/ssl_client_cert.pem"
      SERVICE_PROTOCOL: rest
EOF

echo -e "${GREEN}docker-compose.yml created${NC}"
echo "File generated at $APP_DIR/docker-compose.yml"

# Create Marzban-node SSL certificate file
echo "Creating Marzban-node SSL certificate file..."
touch "$DATA_DIR/ssl_client_cert.pem"

# Open nano editor for SSL certificate
nano "$DATA_DIR/ssl_client_cert.pem"
echo -e "${GREEN}✓ SSL certificate updated!${NC}"

# Configure log rotation for Marzban Node
echo "Configuring log rotation..."
cat > /etc/logrotate.d/marzban-node << 'EOF'
/var/lib/marzban-node/access.log /var/lib/marzban-node/error.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF

# Run logrotate
logrotate -f /etc/logrotate.conf > /dev/null 2>&1

echo -e "${GREEN}Log rotation configured!${NC}"

echo
echo -e "${GREEN}--------------------------------------------${NC}"
echo -e "${GREEN}✓${NC} Configuration files created successfully!"
echo -e "${GREEN}--------------------------------------------${NC}"
echo

echo -e "${GREEN}==============================${NC}"
echo -e "${WHITE}7. Starting Docker containers${NC}"
echo -e "${GREEN}==============================${NC}"
echo

echo "Starting Docker containers..."
cd "$APP_DIR"

# Launching containers
$COMPOSE up -d --remove-orphans
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to start containers. Check: $COMPOSE logs${NC}"
    exit 1
fi

echo "Containers started. Waiting for services to be ready..."
sleep 10

echo "Checking container status..."
$COMPOSE ps

echo -e "${GREEN}✓ Marzban Node started successfully!${NC}"
echo

echo -e "${GREEN}------------------------------------------${NC}"
echo -e "${GREEN}✓${NC} Docker containers started successfully!"
echo -e "${GREEN}------------------------------------------${NC}"
echo

echo -e "${GREEN}---------------------------------------------${NC}"
echo -e "${GREEN}✓${NC} Marzban Node setup completed successfully!"
echo -e "${GREEN}---------------------------------------------${NC}"
echo
echo -e "${CYAN}Check logs with:${NC}"
echo -e "${WHITE}cd /opt/marzban-node && docker compose logs -f${NC}"
echo
echo -e "${CYAN}To complete the setup:${NC}"
echo -e "${WHITE}1. Go to "Node settings" in the Marzban panel.${NC}"
echo -e "${WHITE}2. Fill in the "Name" and "Address" fields.${NC}"
echo -e "${WHITE}3. Click "Update Node".${NC}"
echo

fi
