#!/bin/bash

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
