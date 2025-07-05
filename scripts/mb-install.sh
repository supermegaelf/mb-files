#!/bin/bash

set -e

# Checking root permissions
if [ "$(id -u)" != "0" ]; then
    echo "This command must be run as root."
    exit 1
fi

echo
echo "====================="
echo "MARZBAN PANNEL SETUP"
echo "====================="
echo

# Interactive input for variables

echo -ne "Panel domain (e.g., example.com): "
read PANEL_DOMAIN
while [[ -z "$PANEL_DOMAIN" ]]; do
    echo -e "Panel domain cannot be empty!"
    echo -ne "Panel domain (e.g., example.com): "
    read PANEL_DOMAIN
done

echo -ne "Sub domain (e.g., example.com): "
read SUB_DOMAIN
while [[ -z "$SUB_DOMAIN" ]]; do
    echo -e "Sub domain cannot be empty!"
    echo -ne "Sub domain (e.g., example.com): "
    read SUB_DOMAIN
done

echo -ne "Cloudflare Email: "
read CLOUDFLARE_EMAIL
while [[ -z "$CLOUDFLARE_EMAIL" ]]; do
    echo -e "Cloudflare Email cannot be empty!"
    echo -ne "Cloudflare Email: "
    read CLOUDFLARE_EMAIL
done

echo -ne "Cloudflare API Key: "
read CLOUDFLARE_API_KEY
while [[ -z "$CLOUDFLARE_API_KEY" ]]; do
    echo -e "Cloudflare API Key cannot be empty!"
    echo -ne "Cloudflare API Key: "
    read CLOUDFLARE_API_KEY
done

echo -ne "Node public IP: "
read NODE_PUBLIC_IP
while [[ -z "$NODE_PUBLIC_IP" ]]; do
    echo -e "Node public IP cannot be empty!"
    echo -ne "Node public IP: "
    read NODE_PUBLIC_IP
done

echo
echo "Domains and Cloudflare credentials configured."
echo "Node IP configured: $NODE_PUBLIC_IP"
echo

# System upgrade and package installation
echo "Updating system and installing packages..."
apt-get update
apt-get -y install jq curl unzip wget python3-certbot-dns-cloudflare

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
apt-get -y install unattended-upgrades ufw
echo 'Unattended-Upgrade::Mail "root";' >> /etc/apt/apt.conf.d/50unattended-upgrades 2>/dev/null
echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections > /dev/null 2>&1
dpkg-reconfigure -f noninteractive unattended-upgrades > /dev/null 2>&1
systemctl restart unattended-upgrades > /dev/null 2>&1

# Configuring UFW Firewall
echo "Configuring UFW firewall..."
ufw --force reset > /dev/null 2>&1
ufw allow 22/tcp comment 'SSH' > /dev/null 2>&1
ufw allow 443/tcp comment 'Marzban Dashboard' > /dev/null 2>&1

# Adding Node UFW Rules
echo "Configuring Marznode access for IP: $NODE_PUBLIC_IP"
ufw allow from "$NODE_PUBLIC_IP" to any port 62050 proto tcp comment 'Marznode' > /dev/null 2>&1
ufw allow from "$NODE_PUBLIC_IP" to any port 62051 proto tcp comment 'Marznode' > /dev/null 2>&1

ufw --force enable > /dev/null 2>&1
echo "UFW firewall configured successfully!"

# Docker Installation
if ! command -v docker >/dev/null 2>&1; then
    echo "Adding Docker repository..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | tee /etc/apt/keyrings/docker.asc > /dev/null
    chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    echo "Installing Docker..."
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    echo "Docker installed successfully"
fi

# Defining docker compose command
if docker compose version >/dev/null 2>&1; then
    COMPOSE='docker compose'
elif docker-compose version >/dev/null 2>&1; then
    COMPOSE='docker-compose'
else
    echo "docker compose not found"
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
        echo "Unsupported architecture: $(uname -m)"
        echo "Supported: x86_64, aarch64"
        exit 1
        ;;
esac

echo "Detected architecture: $ARCH"

# YQ installation
if ! command -v yq &>/dev/null; then
    echo "Installing yq..."
    yq_url="https://github.com/mikefarah/yq/releases/latest/download/${yq_binary}"
    echo "Downloading yq from ${yq_url}..."
    
    curl -L "$yq_url" -o /usr/local/bin/yq
    chmod +x /usr/local/bin/yq
    echo "yq installed successfully!"
    
    export PATH="/usr/local/bin:$PATH"
    hash -r
else
    echo "yq is already installed."
fi

# Path variables
INSTALL_DIR="/opt"
APP_NAME="marzban"
APP_DIR="$INSTALL_DIR/$APP_NAME"
DATA_DIR="/var/lib/$APP_NAME"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"
ENV_FILE="$APP_DIR/.env"

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
    echo "Cloudflare credentials file created."
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

echo "SSL certificates configured successfully!"
echo

# Nginx Installation and Configuration
echo "Installing Nginx from official repository..."
curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor -o /etc/apt/keyrings/nginx-signing.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/nginx-signing.gpg] http://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" > /etc/apt/sources.list.d/nginx.list
apt update && apt install nginx -y

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
nginx -t && systemctl restart nginx && systemctl enable nginx

echo "Nginx configured successfully!"
echo "Dashboard URL: https://dash.$PANEL_DOMAIN"
echo "Subscription URL: https://$SUB_DOMAIN"
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

echo "Using MariaDB as database"
echo "File generated at $APP_DIR/docker-compose.yml"

echo "Creating .env configuration file"

# Data generation
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

echo ".env file created with database configuration"

sleep 3

echo "Adding database configuration to .env file..."

# Adding the database configuration to the .env file
cat >> "$ENV_FILE" << EOF

# Database configuration
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=marzban
MYSQL_USER=marzban
MYSQL_PASSWORD=$MYSQL_PASSWORD

# SQLAlchemy Database URL
SQLALCHEMY_DATABASE_URL="mysql+pymysql://marzban:${MYSQL_PASSWORD}@127.0.0.1:3306/marzban"
EOF

echo "File saved in $APP_DIR/.env"

echo "Creating custom xray config file"
cat > "$DATA_DIR/xray_config.json" << 'EOF'
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
      "tag": "Shadowsocks TCP",
      "listen": "0.0.0.0",
      "port": 1080,
      "protocol": "shadowsocks",
      "settings": {
        "clients": [],
        "network": "tcp,udp"
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
echo "Custom xray config created at $DATA_DIR/xray_config.json"

echo "Downloading custom subscription template..."
mkdir -p /var/lib/marzban/templates/subscription
wget -q https://raw.githubusercontent.com/supermegaelf/mb-files/main/pages/sub/index.html -O /var/lib/marzban/templates/subscription/index.html > /dev/null 2>&1

# Replacing example.com with actual panel domain
sed -i "s/example\.com/$PANEL_DOMAIN/g" /var/lib/marzban/templates/subscription/index.html

echo "Custom subscription template configured at /var/lib/marzban/templates/subscription/index.html"

echo "Downloading enhanced subscription router..."
wget -O /var/lib/marzban/subscription.py "https://raw.githubusercontent.com/hydraponique/roscomvpn-happ-routing/main/Auto-routing%20for%20Non-json%20Marzban/subscription.py" > /dev/null 2>&1
echo "Enhanced subscription router downloaded to /var/lib/marzban/subscription.py"

echo "Marzban's files downloaded successfully"

echo "Installing marzban script"
FETCH_REPO="Gozargah/Marzban-scripts"
SCRIPT_URL="https://github.com/$FETCH_REPO/raw/master/marzban.sh"
curl -sSL $SCRIPT_URL | install -m 755 /dev/stdin /usr/local/bin/marzban
echo "marzban script installed successfully"

echo "Downloading and installing Xray-core..."

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

echo "Xray-core installed successfully to /usr/local/bin/xray"

# Adding the path to Xray to the .env file
echo "Starting Docker containers..."
cd "$APP_DIR"

# Launching containers
$COMPOSE up -d --remove-orphans

echo "Containers started. Waiting for services to be ready..."
sleep 30

echo "Checking container status..."
$COMPOSE ps

# Functionality check
if curl -s "http://localhost:8000" > /dev/null; then
    echo "✅ Marzban installation completed successfully!"
    echo
    echo "🌐 Dashboard URL: https://dash.$PANEL_DOMAIN/dashboard"
    echo
    echo "🔒 Create admin: marzban cli admin create --sudo -u admin"
    echo
    echo "🔍 Check logs with: marzban logs"
    echo
else
    echo
    echo "❌ There might be an issue with Marzban startup."
    echo
    echo "🔍 Check logs with: marzban logs"
    echo
fi
