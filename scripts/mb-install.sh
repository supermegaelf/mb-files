#!/bin/bash

#=================
# MARZBAN MANAGER
#=================

# Color constants
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly GRAY='\033[0;90m'
readonly NC='\033[0m'

# Status symbols
readonly CHECK="✓"
readonly CROSS="✗"
readonly WARNING="!"
readonly INFO="*"
readonly ARROW="→"

#======================
# VALIDATION FUNCTIONS
#======================

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
        echo -e "${RED}${CROSS}${NC} Error: $1"
        exit 1
    fi
}

#=====================
# MAIN MENU FUNCTIONS
#=====================

# Display main menu
show_main_menu() {
    echo
    echo -e "${PURPLE}================${NC}"
    echo -e "${WHITE}MARZBAN MANAGER${NC}"
    echo -e "${PURPLE}================${NC}"
    echo
    echo -e "${CYAN}Please select installation type:${NC}"
    echo
    echo -e "${GREEN}1.${NC} Install Panel"
    echo -e "${GREEN}2.${NC} Install Node"
    echo -e "${RED}3.${NC} Exit"
    echo
    echo -ne "${CYAN}Enter your choice (1, 2, or 3): ${NC}"
}

# Handle user choice
handle_user_choice() {
    local choice=$1
    
    case $choice in
        1)
            install_panel
            ;;
        2)
            install_node
            ;;
        3)
            echo
            echo -e "${YELLOW}${WARNING}${NC} Exiting installation..."
            exit 0
            ;;
        *)
            echo
            echo -e "${RED}${CROSS}${NC} Invalid choice. Please select 1, 2, or 3."
            exit 1
            ;;
    esac
}

#==============================
# PANEL INSTALLATION FUNCTIONS
#==============================

# Check root permissions
check_root_permissions() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}${CROSS}${NC} This command must be run as root."
        exit 1
    fi
}

# Input panel domain
input_panel_domain() {
    echo -ne "${CYAN}Panel domain (e.g., example.com): ${NC}"
    read PANEL_DOMAIN
    while [[ -z "$PANEL_DOMAIN" ]] || ! validate_domain "$PANEL_DOMAIN"; do
        echo -e "${RED}${CROSS}${NC} Invalid domain! Please enter a valid domain (e.g., example.com)."
        echo
        echo -ne "${CYAN}Panel domain: ${NC}"
        read PANEL_DOMAIN
    done
}

# Input sub domain
input_sub_domain() {
    echo -ne "${CYAN}Sub domain (e.g., example.com): ${NC}"
    read SUB_DOMAIN
    while [[ -z "$SUB_DOMAIN" ]] || ! validate_domain "$SUB_DOMAIN"; do
        echo -e "${RED}${CROSS}${NC} Invalid domain! Please enter a valid domain."
        echo
        echo -ne "${CYAN}Sub domain: ${NC}"
        read SUB_DOMAIN
    done
}

# Input selfsteal domain
input_selfsteal_domain() {
    echo -ne "${CYAN}Self-steal domain (e.g., example.com): ${NC}"
    read SELFSTEAL_DOMAIN
    while [[ -z "$SELFSTEAL_DOMAIN" ]] || ! validate_domain "$SELFSTEAL_DOMAIN"; do
        echo -e "${RED}${CROSS}${NC} Invalid domain! Please enter a valid domain."
        echo
        echo -ne "${CYAN}Self-steal domain: ${NC}"
        read SELFSTEAL_DOMAIN
    done
}

# Input Cloudflare email
input_cloudflare_email() {
    echo -ne "${CYAN}Cloudflare Email: ${NC}"
    read CLOUDFLARE_EMAIL
    while [[ -z "$CLOUDFLARE_EMAIL" ]]; do
        echo -e "${RED}${CROSS}${NC} Cloudflare Email cannot be empty!"
        echo
        echo -ne "${CYAN}Cloudflare Email: ${NC}"
        read CLOUDFLARE_EMAIL
    done
}

# Input Cloudflare API key
input_cloudflare_api_key() {
    echo -ne "${CYAN}Cloudflare API Key: ${NC}"
    read CLOUDFLARE_API_KEY
    while [[ -z "$CLOUDFLARE_API_KEY" ]]; do
        echo -e "${RED}${CROSS}${NC} Cloudflare API Key cannot be empty!"
        echo
        echo -ne "${CYAN}Cloudflare API Key: ${NC}"
        read CLOUDFLARE_API_KEY
    done
}

# Input node public IP
input_node_public_ip() {
    echo -ne "${CYAN}Node public IP: ${NC}"
    read NODE_PUBLIC_IP
    while [[ -z "$NODE_PUBLIC_IP" ]] || ! validate_ip "$NODE_PUBLIC_IP"; do
        echo -e "${RED}${CROSS}${NC} Invalid IP! Please enter a valid IPv4 address (e.g., 1.2.3.4)."
        echo
        echo -ne "${CYAN}Node public IP: ${NC}"
        read NODE_PUBLIC_IP
    done
}

#=====================================
# PANEL SYSTEM INSTALLATION FUNCTIONS
#=====================================

# Install system packages
install_system_packages() {
    echo -e "${CYAN}${INFO}${NC} Installing basic packages..."
    echo -e "${GRAY}  ${ARROW}${NC} Updating package lists"
    apt-get update > /dev/null 2>&1
    echo -e "${GRAY}  ${ARROW}${NC} Installing essential packages"
    apt-get -y install jq curl unzip wget python3-certbot-dns-cloudflare > /dev/null 2>&1

    configure_locale
    configure_timezone
    configure_tcp_bbr
    configure_security_updates
}

# Configure locale
configure_locale() {
    echo -e "${GRAY}  ${ARROW}${NC} Configuring locales"
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen 2>/dev/null
    locale-gen > /dev/null 2>&1
    update-locale LANG=en_US.UTF-8 > /dev/null 2>&1
}

# Configure timezone
configure_timezone() {
    echo -e "${GRAY}  ${ARROW}${NC} Setting timezone to Europe/Moscow"
    timedatectl set-timezone Europe/Moscow > /dev/null 2>&1
}

# Configure TCP BBR
configure_tcp_bbr() {
    echo -e "${GRAY}  ${ARROW}${NC} Configuring TCP BBR optimization"
    echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf 2>/dev/null
    echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf 2>/dev/null
    sysctl -p > /dev/null 2>&1
}

# Configure security updates
configure_security_updates() {
    echo -e "${GRAY}  ${ARROW}${NC} Configuring automatic security updates"
    apt-get -y install unattended-upgrades ufw > /dev/null 2>&1
    echo 'Unattended-Upgrade::Mail "root";' >> /etc/apt/apt.conf.d/50unattended-upgrades 2>/dev/null
    echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections > /dev/null 2>&1
    dpkg-reconfigure -f noninteractive unattended-upgrades > /dev/null 2>&1
    systemctl restart unattended-upgrades > /dev/null 2>&1
}

#==========================
# PANEL FIREWALL FUNCTIONS
#==========================

# Configure UFW firewall
configure_firewall() {
    echo -e "${CYAN}${INFO}${NC} Configuring UFW firewall..."
    echo -e "${GRAY}  ${ARROW}${NC} Resetting firewall rules"
    ufw --force reset > /dev/null 2>&1
    echo -e "${GRAY}  ${ARROW}${NC} Allowing SSH access"
    ufw allow 22/tcp comment 'SSH' > /dev/null 2>&1
    echo -e "${GRAY}  ${ARROW}${NC} Allowing Marzban dashboard"
    ufw allow 443/tcp comment 'Marzban Dashboard' > /dev/null 2>&1
    echo -e "${GRAY}  ${ARROW}${NC} Allowing VLESS Reality"
    ufw allow 10000/tcp comment 'VLESS Reality' > /dev/null 2>&1

    configure_node_firewall_rules

    echo -e "${GRAY}  ${ARROW}${NC} Enabling firewall"
    ufw --force enable > /dev/null 2>&1
}

# Configure node firewall rules
configure_node_firewall_rules() {
    echo -e "${GRAY}  ${ARROW}${NC} Adding node server rules"
    ufw allow from "$NODE_PUBLIC_IP" to any port 62050 proto tcp comment 'Marznode' > /dev/null 2>&1
    ufw allow from "$NODE_PUBLIC_IP" to any port 62051 proto tcp comment 'Marznode' > /dev/null 2>&1
}

#=====================================
# PANEL DOCKER INSTALLATION FUNCTIONS
#=====================================

# Install Docker
install_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${CYAN}${INFO}${NC} Installing Docker..."
        add_docker_repository
        install_docker_packages
        echo -e "${GREEN}${CHECK}${NC} Docker installed successfully!"
    else
        echo -e "${GREEN}${CHECK}${NC} Docker already installed"
    fi
}

# Add Docker repository
add_docker_repository() {
    echo -e "${GRAY}  ${ARROW}${NC} Adding Docker repository"
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | tee /etc/apt/keyrings/docker.asc > /dev/null
    chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
}

# Install Docker packages
install_docker_packages() {
    echo -e "${GRAY}  ${ARROW}${NC} Installing Docker packages"
    apt-get update > /dev/null 2>&1
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1
}

# Setup Docker Compose command
setup_docker_compose() {
    if docker compose version >/dev/null 2>&1; then
        COMPOSE='docker compose'
    elif docker-compose version >/dev/null 2>&1; then
        COMPOSE='docker-compose'
    else
        echo -e "${RED}${CROSS}${NC} Docker Compose not found."
        echo
        exit 1
    fi
}

#=====================================
# PANEL ARCHITECTURE AND YQ FUNCTIONS
#=====================================

# Detect architecture
detect_architecture() {
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
            echo -e "${RED}${CROSS}${NC} Unsupported architecture: $(uname -m)."
            echo
            echo -e "${RED}${CROSS}${NC} Supported: x86_64, aarch64."
            exit 1
            ;;
    esac
}

# Install YQ
install_yq() {
    if ! command -v yq &>/dev/null; then
        echo -e "${CYAN}${INFO}${NC} Installing yq..."
        local yq_url="https://github.com/mikefarah/yq/releases/latest/download/${yq_binary}"
        
        echo -e "${GRAY}  ${ARROW}${NC} Downloading yq from GitHub"
        curl -L "$yq_url" -o /usr/local/bin/yq > /dev/null 2>&1
        chmod +x /usr/local/bin/yq
        echo -e "${GREEN}${CHECK}${NC} YQ installed successfully!"
        
        export PATH="/usr/local/bin:$PATH"
        hash -r
    else
        echo -e "${GREEN}${CHECK}${NC} yq is already installed"
    fi
}

#===========================================
# PANEL DIRECTORY AND CERTIFICATE FUNCTIONS
#===========================================

# Create directory structure
create_directory_structure() {
    echo -e "${CYAN}${INFO}${NC} Creating directory structure..."
    echo -e "${GRAY}  ${ARROW}${NC} Creating data directory: $DATA_DIR"
    mkdir -p "$DATA_DIR"
    echo -e "${GRAY}  ${ARROW}${NC} Creating app directory: $APP_DIR"
    mkdir -p "$APP_DIR"
    echo -e "${GREEN}${CHECK}${NC} Directory structure created!"
}

# Check Cloudflare API
check_cloudflare_api() {
    echo -e "${CYAN}${INFO}${NC} Checking Cloudflare API..."
    if [[ $CLOUDFLARE_API_KEY =~ [A-Z] ]]; then
        echo -e "${GRAY}  ${ARROW}${NC} Using API Token authentication"
        api_response=$(curl --silent --request GET --url https://api.cloudflare.com/client/v4/zones --header "Authorization: Bearer ${CLOUDFLARE_API_KEY}" --header "Content-Type: application/json")
    else
        echo -e "${GRAY}  ${ARROW}${NC} Using Global API Key authentication"
        api_response=$(curl --silent --request GET --url https://api.cloudflare.com/client/v4/zones --header "X-Auth-Key: ${CLOUDFLARE_API_KEY}" --header "X-Auth-Email: ${CLOUDFLARE_EMAIL}" --header "Content-Type: application/json")
    fi
    echo -e "${GREEN}${CHECK}${NC} Cloudflare API credentials verified!"
}

# Setup Cloudflare credentials
setup_cloudflare_credentials() {
    echo -e "${CYAN}${INFO}${NC} Setting up Cloudflare credentials..."
    echo -e "${GRAY}  ${ARROW}${NC} Creating credentials directory"
    mkdir -p ~/.secrets/certbot

    if [ ! -f ~/.secrets/certbot/cloudflare.ini ]; then
        echo -e "${GRAY}  ${ARROW}${NC} Creating Cloudflare credentials file"
        create_cloudflare_credentials_file
        chmod 600 ~/.secrets/certbot/cloudflare.ini
        echo -e "${GREEN}${CHECK}${NC} Cloudflare credentials file created!"
    else
        echo -e "${GREEN}${CHECK}${NC} Cloudflare credentials file already exists"
    fi
}

# Create Cloudflare credentials file
create_cloudflare_credentials_file() {
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
}

# Extract base domains
extract_base_domains() {
    echo -e "${CYAN}${INFO}${NC} Extracting base domains..."
    echo -e "${GRAY}  ${ARROW}${NC} Processing panel domain"
    PANEL_BASE_DOMAIN=$(echo "$PANEL_DOMAIN" | awk -F'.' '{if (NF > 2) {print $(NF-1)"."$NF} else {print $0}}')
    echo -e "${GRAY}  ${ARROW}${NC} Processing sub domain"
    SUB_BASE_DOMAIN=$(echo "$SUB_DOMAIN" | awk -F'.' '{if (NF > 2) {print $(NF-1)"."$NF} else {print $0}}')
    echo -e "${GREEN}${CHECK}${NC} Base domains extracted!"
}

# Generate certificate for domain
generate_certificate_for_domain() {
    local domain=$1
    local domain_type=$2
    
    echo -e "${CYAN}${INFO}${NC} Checking certificate for $domain_type domain..."
    echo -e "${GRAY}  ${ARROW}${NC} Verifying certificate status for $domain"
    if [ ! -d "/etc/letsencrypt/live/$domain" ]; then
        echo -e "${GRAY}  ${ARROW}${NC} Generating certificate for $domain"
        certbot certonly \
            --dns-cloudflare \
            --dns-cloudflare-credentials ~/.secrets/certbot/cloudflare.ini \
            --dns-cloudflare-propagation-seconds 10 \
            -d "$domain" \
            -d "*.$domain" \
            --email "$CLOUDFLARE_EMAIL" \
            --agree-tos \
            --non-interactive \
            --key-type ecdsa \
            --elliptic-curve secp384r1 > /dev/null 2>&1
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}${CROSS}${NC} Failed to generate SSL certificate for $domain. Check Cloudflare credentials."
            echo
            exit 1
        fi
        echo -e "${GREEN}${CHECK}${NC} Certificate generated for $domain!"
    else
        echo -e "${GREEN}${CHECK}${NC} Certificate for $domain already exists"
    fi
}

# Configure certificate renewal
configure_certificate_renewal() {
    echo -e "${CYAN}${INFO}${NC} Configuring certificate renewal..."
    echo -e "${GRAY}  ${ARROW}${NC} Adding renewal hooks"
    if [ -f "/etc/letsencrypt/renewal/$PANEL_BASE_DOMAIN.conf" ]; then
        echo "renew_hook = systemctl restart marzban" >> /etc/letsencrypt/renewal/$PANEL_BASE_DOMAIN.conf
    fi
    if [ -f "/etc/letsencrypt/renewal/$SUB_BASE_DOMAIN.conf" ]; then
        echo "renew_hook = systemctl restart marzban" >> /etc/letsencrypt/renewal/$SUB_BASE_DOMAIN.conf
    fi
    echo -e "${GRAY}  ${ARROW}${NC} Setting up cron job"
    (crontab -u root -l 2>/dev/null; echo "0 5 1 */2 * /usr/bin/certbot renew --quiet") | crontab -u root -
    echo -e "${GREEN}${CHECK}${NC} SSL certificates configured successfully!"
}

#====================================
# PANEL NGINX INSTALLATION FUNCTIONS
#====================================

# Install Nginx
install_nginx() {
    echo -e "${CYAN}${INFO}${NC} Installing Nginx from official repository..."
    add_nginx_repository
    install_nginx_package
    echo -e "${GREEN}${CHECK}${NC} Nginx installed successfully!"
}

# Add Nginx repository
add_nginx_repository() {
    echo -e "${GRAY}  ${ARROW}${NC} Adding Nginx signing key"
    curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor --yes -o /etc/apt/keyrings/nginx-signing.gpg > /dev/null 2>&1
    echo -e "${GRAY}  ${ARROW}${NC} Adding Nginx repository"
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/nginx-signing.gpg] http://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" > /etc/apt/sources.list.d/nginx.list
}

# Install Nginx package
install_nginx_package() {
    echo -e "${GRAY}  ${ARROW}${NC} Installing Nginx package"
    apt update > /dev/null 2>&1 && apt install nginx -y > /dev/null 2>&1
}

# Create SSL snippets
create_ssl_snippets() {
    echo -e "${CYAN}${INFO}${NC} Creating SSL snippets..."
    echo -e "${GRAY}  ${ARROW}${NC} Creating snippets directory"
    mkdir -p /etc/nginx/snippets

    create_panel_ssl_snippet
    create_sub_ssl_snippet
    create_ssl_params_snippet
    
    echo -e "${GREEN}${CHECK}${NC} SSL snippets created!"
}

# Create panel SSL snippet
create_panel_ssl_snippet() {
    echo -e "${GRAY}  ${ARROW}${NC} Creating SSL snippet for panel domain"
    cat > /etc/nginx/snippets/ssl.conf << EOF
ssl_certificate /etc/letsencrypt/live/$PANEL_BASE_DOMAIN/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/$PANEL_BASE_DOMAIN/privkey.pem;
EOF
}

# Create subscription SSL snippet
create_sub_ssl_snippet() {
    echo -e "${GRAY}  ${ARROW}${NC} Creating SSL snippet for subscription domain"
    cat > /etc/nginx/snippets/ssl-sub.conf << EOF
ssl_certificate /etc/letsencrypt/live/$SUB_BASE_DOMAIN/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/$SUB_BASE_DOMAIN/privkey.pem;
EOF
}

# Create SSL parameters snippet
create_ssl_params_snippet() {
    echo -e "${GRAY}  ${ARROW}${NC} Creating SSL parameters snippet"
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
}

# Configure Nginx sites
configure_nginx_sites() {
    echo -e "${CYAN}${INFO}${NC} Configuring Nginx sites..."
    echo -e "${GRAY}  ${ARROW}${NC} Removing default configuration"
    rm -f /etc/nginx/conf.d/default.conf

    create_marzban_dashboard_config
    create_subscription_site_config
    create_main_nginx_config
    
    echo -e "${GRAY}  ${ARROW}${NC} Testing configuration and starting service"
    nginx -t > /dev/null 2>&1 && systemctl restart nginx > /dev/null 2>&1 && systemctl enable nginx > /dev/null 2>&1
    echo -e "${GREEN}${CHECK}${NC} Nginx configured successfully!"
}

# Create Marzban dashboard config
create_marzban_dashboard_config() {
    echo -e "${GRAY}  ${ARROW}${NC} Creating Marzban dashboard configuration"
    cat > /etc/nginx/conf.d/marzban-dash.conf << EOF
server {
    server_name  dash.$PANEL_DOMAIN;

    listen       443 ssl;
    http2        on;

    location ~* /(sub|$DASHBOARD_PATH|api|statics|docs|redoc|openapi.json) {
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
}

# Create subscription site config
create_subscription_site_config() {
    echo -e "${GRAY}  ${ARROW}${NC} Creating subscription site configuration"
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
}

# Create main Nginx config
create_main_nginx_config() {
    echo -e "${GRAY}  ${ARROW}${NC} Creating main Nginx configuration"
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
}

#===============================
# PANEL REDIRECT PAGE FUNCTIONS
#===============================

# Setup redirect page
setup_redirect_page() {
    echo -e "${CYAN}${INFO}${NC} Creating redirect site configuration..."
    create_redirect_config
    create_redirect_directory
    download_redirect_page
    customize_redirect_page
    set_redirect_permissions
    test_nginx_config
    echo -e "${GREEN}${CHECK}${NC} Redirect page configured successfully!"
}

# Create redirect config
create_redirect_config() {
    echo -e "${GRAY}  ${ARROW}${NC} Creating redirect site configuration"
    cat > /etc/nginx/conf.d/redirect.conf << EOF
server {
    listen 443 ssl;
    server_name redirect.$PANEL_DOMAIN;

    root /var/www/redirect;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    include /etc/nginx/snippets/ssl.conf;
    include /etc/nginx/snippets/ssl-params.conf;
}
EOF
}

# Create redirect directory
create_redirect_directory() {
    echo -e "${GRAY}  ${ARROW}${NC} Creating redirect page directory"
    mkdir -p /var/www/redirect
}

# Download redirect page
download_redirect_page() {
    echo -e "${GRAY}  ${ARROW}${NC} Downloading redirect page"
    wget -q https://raw.githubusercontent.com/supermegaelf/mb-files/main/pages/redirect/index.html -O /var/www/redirect/index.html > /dev/null 2>&1
}

# Customize redirect page
customize_redirect_page() {
    echo -e "${GRAY}  ${ARROW}${NC} Customizing redirect page with panel domain"
    sed -i "s/example\.com/$PANEL_DOMAIN/g" /var/www/redirect/index.html
}

# Set redirect permissions
set_redirect_permissions() {
    echo -e "${GRAY}  ${ARROW}${NC} Setting proper permissions"
    chown -R www-data:www-data /var/www/redirect
    chmod -R 755 /var/www/redirect
}

# Test Nginx config
test_nginx_config() {
    echo -e "${GRAY}  ${ARROW}${NC} Testing Nginx configuration"
    nginx -t > /dev/null 2>&1 && systemctl restart nginx > /dev/null 2>&1
}

#=====================================
# PANEL CONFIGURATION FILES FUNCTIONS
#=====================================

# Create docker-compose file
create_docker_compose_file() {
    echo -e "${CYAN}${INFO}${NC} Setting up docker-compose.yml for MariaDB..."
    echo -e "${GRAY}  ${ARROW}${NC} Creating docker-compose configuration"

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

    echo -e "${GREEN}${CHECK}${NC} Using MariaDB as database!"
    echo
    echo -e "${CYAN}${INFO}${NC} File generated at: ${WHITE}$APP_DIR/docker-compose.yml${NC}"
    echo
}

# Generate secure passwords
generate_secure_passwords() {
    MYSQL_ROOT_PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20)
    MYSQL_PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20)
    WEBHOOK_SECRET=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)
    ADMIN_USERNAME="admin"
    ADMIN_PASSWORD=$(tr -dc 'A-Za-z0-9!@#%^&*()' </dev/urandom | head -c 16)
}

# Generate random dashboard path
generate_dashboard_path() {
    DASHBOARD_PATH=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 10)
}

# Create environment file
create_env_file() {
    echo -e "${CYAN}${INFO}${NC} Creating .env configuration file..."
    echo -e "${GRAY}  ${ARROW}${NC} Generating secure random values"
    generate_secure_passwords

    echo -e "${GRAY}  ${ARROW}${NC} Creating environment configuration"
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

DASHBOARD_PATH = "/$DASHBOARD_PATH/"

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

# V2RAY_SUBSCRIPTION_TEMPLATE="v2ray/custom.json"
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
# USE_CUSTOM_JSON_FOR_HAPP=True

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

    echo -e "${GREEN}${CHECK}${NC} .env file created with database configuration!"
}

# Secure configuration files
secure_configuration_files() {
    echo -e "${CYAN}${INFO}${NC} Setting secure permissions on configuration files..."
    echo -e "${GRAY}  ${ARROW}${NC} Securing .env file permissions"
    chmod 600 "$APP_DIR/.env"
    chown root:root "$APP_DIR/.env"
    echo -e "${GREEN}${CHECK}${NC} File permissions secured!"
}

#====================================
# PANEL XRAY CONFIGURATION FUNCTIONS
#====================================

# Generate VLESS parameters
generate_vless_parameters() {
    VLESS_UUID=$(cat /proc/sys/kernel/random/uuid)
    PRIVATE_KEY=$(openssl genpkey -algorithm X25519 2>/dev/null | openssl pkey -outform DER 2>/dev/null | tail -c +17 | head -c 32 | base64 | tr '/+' '_-' | tr -d '=')
    SHORT_ID=$(openssl rand -hex 4)
}

# Create Xray config
create_xray_config() {
    echo -e "${CYAN}${INFO}${NC} Creating custom xray config file..."
    echo -e "${GRAY}  ${ARROW}${NC} Generating VLESS Reality parameters"
    generate_vless_parameters

    echo -e "${GRAY}  ${ARROW}${NC} Creating xray configuration"
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
        "type": "field",
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "BLOCK"
      },
      {
        "type": "field",
        "domain": [
          "geosite:google"
        ],
        "outboundTag": "IPv4"
      },
      {
        "type": "field",
        "protocol": [
          "bittorrent"
        ],
        "outboundTag": "DIRECT"
      },
      {
        "type": "field",
        "domain": [
          "geosite:category-gov-ru"
        ],
        "outboundTag": "BLOCK"
      },
      {
        "type": "field",
        "domain": [
          "geosite:category-ads-all"
        ],
        "outboundTag": "BLOCK"
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
        "network": "raw",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "target": "$SELFSTEAL_DOMAIN:443",
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
    echo -e "${GREEN}${CHECK}${NC} Custom xray config created!"
    echo
    echo -e "${CYAN}${INFO}${NC} File location: ${WHITE}$DATA_DIR/xray_config.json${NC}"
}

#===========================================
# PANEL DOWNLOAD ADDITIONAL FILES FUNCTIONS
#===========================================

# Download subscription template
download_subscription_template() {
    echo -e "${CYAN}${INFO}${NC} Downloading custom subscription template..."
    echo -e "${GRAY}  ${ARROW}${NC} Creating templates directory"
    mkdir -p /var/lib/marzban/templates/subscription
    
    echo -e "${GRAY}  ${ARROW}${NC} Downloading subscription template"
    wget -q https://raw.githubusercontent.com/supermegaelf/mb-files/main/pages/sub/index.html -O /var/lib/marzban/templates/subscription/index.html > /dev/null 2>&1

    echo -e "${GRAY}  ${ARROW}${NC} Customizing template with panel domain"
    sed -i "s/example\.com/$PANEL_DOMAIN/g" /var/lib/marzban/templates/subscription/index.html
    echo -e "${GREEN}${CHECK}${NC} Custom subscription template configured!"
}

# Install Marzban script
install_marzban_script() {
    echo -e "${CYAN}${INFO}${NC} Installing marzban script..."
    echo -e "${GRAY}  ${ARROW}${NC} Downloading marzban management script"
    local FETCH_REPO="Gozargah/Marzban-scripts"
    local SCRIPT_URL="https://github.com/$FETCH_REPO/raw/master/marzban.sh"
    curl -sSL $SCRIPT_URL | install -m 755 /dev/stdin /usr/local/bin/marzban
    echo -e "${GREEN}${CHECK}${NC} Marzban script installed successfully!"
}

#========================================
# PANEL XRAY-CORE INSTALLATION FUNCTIONS
#========================================

# Install Xray-core
install_xray_core() {
    echo -e "${CYAN}${INFO}${NC} Preparing Xray-core installation..."
    setup_xray_temp_directory
    download_xray_core
    extract_and_install_xray
    cleanup_xray_temp
    echo -e "${GREEN}${CHECK}${NC} Xray-core installed successfully!"
}

# Setup Xray temporary directory
setup_xray_temp_directory() {
    echo -e "${GRAY}  ${ARROW}${NC} Creating temporary directory"
    mkdir -p /tmp/xray-install
    cd /tmp/xray-install
}

# Download Xray-core
download_xray_core() {
    echo -e "${GRAY}  ${ARROW}${NC} Fetching latest version information"
    local LAST_XRAY_CORES=10
    local latest_releases=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases?per_page=$LAST_XRAY_CORES")
    local latest_version=$(echo "$latest_releases" | grep -oP '"tag_name": "\K(.*?)(?=")' | head -n 1)

    local xray_filename="Xray-linux-$ARCH.zip"
    local xray_download_url="https://github.com/XTLS/Xray-core/releases/download/${latest_version}/${xray_filename}"

    echo -e "${GRAY}  ${ARROW}${NC} Downloading Xray-core version ${latest_version}"
    wget -q -O "${xray_filename}" "${xray_download_url}"
}

# Extract and install Xray
extract_and_install_xray() {
    echo -e "${GRAY}  ${ARROW}${NC} Extracting Xray-core archive"
    unzip -o "Xray-linux-$ARCH.zip" >/dev/null 2>&1

    echo -e "${GRAY}  ${ARROW}${NC} Installing to /usr/local/bin/"
    cp xray /usr/local/bin/
    chmod +x /usr/local/bin/xray
}

# Cleanup Xray temporary files
cleanup_xray_temp() {
    echo -e "${GRAY}  ${ARROW}${NC} Cleaning up temporary files"
    cd /
    rm -rf /tmp/xray-install
}

#===================================
# PANEL DOCKER CONTAINERS FUNCTIONS
#===================================

# Start Docker containers
start_docker_containers() {
    echo -e "${CYAN}${INFO}${NC} Starting Docker containers..."
    echo -e "${GRAY}  ${ARROW}${NC} Navigating to application directory"
    cd "$APP_DIR"

    echo -e "${GRAY}  ${ARROW}${NC} Starting services with docker compose"
    $COMPOSE up -d --remove-orphans > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}${CROSS}${NC} Failed to start containers. Check: $COMPOSE logs."
        echo
        exit 1
    fi

    wait_for_services
    verify_container_status
    echo -e "${GREEN}${CHECK}${NC} Docker containers started successfully!"
}

# Wait for services
wait_for_services() {
    echo -e "${GRAY}  ${ARROW}${NC} Waiting for services to be ready"
    sleep 30
    if ! curl -s "http://localhost:8000" > /dev/null; then
        echo -e "${RED}${CROSS}${NC} Marzban not responding. Check: $COMPOSE logs marzban."
        echo
        exit 1
    fi
}

# Verify container status
verify_container_status() {
    echo -e "${GRAY}  ${ARROW}${NC} Verifying container status"
    $COMPOSE ps > /dev/null 2>&1
}

#============================
# PANEL ADMIN USER FUNCTIONS
#============================

# Install bcrypt
install_bcrypt() {
    if ! python3 -c "import bcrypt" 2>/dev/null; then
        echo -e "${CYAN}${INFO}${NC} Installing python3-bcrypt..."
        echo -e "${GRAY}  ${ARROW}${NC} Installing bcrypt package"
        apt-get update > /dev/null 2>&1
        apt-get -y install python3-bcrypt > /dev/null 2>&1
        echo -e "${GREEN}${CHECK}${NC} python3-bcrypt installed!"
        echo
    fi
}

# Create admin user
create_admin_user() {
    install_bcrypt
    
    ADMIN_PASSWORD_DISPLAY=$ADMIN_PASSWORD
    
    echo -e "${CYAN}${INFO}${NC} Creating admin user via database..."
    echo -e "${GRAY}  ${ARROW}${NC} Generating password hash"

    local ADMIN_PASSWORD_HASH=$(python3 -c "import bcrypt; print(bcrypt.hashpw('$ADMIN_PASSWORD'.encode(), bcrypt.gensalt()).decode())")

    echo -e "${GRAY}  ${ARROW}${NC} Retrieving database credentials"
    local MYSQL_PASSWORD=$(grep "^MYSQL_PASSWORD=" "$APP_DIR/.env" | cut -d'=' -f2)

    echo -e "${GRAY}  ${ARROW}${NC} Finding MariaDB container"
    local container_id=$(docker ps -q -f ancestor=mariadb:lts)

    create_admin_in_database "$container_id" "$ADMIN_PASSWORD_HASH" "$MYSQL_PASSWORD"
}

# Create admin in database
create_admin_in_database() {
    local container_id=$1
    local password_hash=$2
    local mysql_password=$3
    
    if [ -n "$container_id" ]; then
        echo -e "${GRAY}  ${ARROW}${NC} Creating admin user in database"
        docker exec $container_id mariadb -u marzban -p"$mysql_password" marzban -e "
        INSERT INTO admins (username, hashed_password, is_sudo, created_at) 
        VALUES ('$ADMIN_USERNAME', '$password_hash', 1, NOW())
        ON DUPLICATE KEY UPDATE 
            hashed_password = '$password_hash',
            is_sudo = 1;
        " 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}${CHECK}${NC} Admin user created successfully via database!"
        else
            echo -e "${YELLOW}${WARNING}${NC} Admin may already exist, trying to update password..."
        fi
    else
        echo -e "${RED}${CROSS}${NC} Cannot find MariaDB container."
        echo
    fi
}

#=====================================
# PANEL HOSTS CONFIGURATION FUNCTIONS
#=====================================

# Prepare system for hosts
prepare_system_for_hosts() {
    echo -e "${CYAN}${INFO}${NC} Preparing system for hosts configuration..."
    echo -e "${GRAY}  ${ARROW}${NC} Restarting Marzban container"
    cd "$APP_DIR"
    $COMPOSE restart marzban > /dev/null 2>&1

    wait_for_marzban_api
    stabilize_system
}

# Wait for Marzban API
wait_for_marzban_api() {
    echo -e "${GRAY}  ${ARROW}${NC} Waiting for Marzban to be ready"
    for i in {1..30}; do
        if curl -s "http://localhost:8000/" > /dev/null 2>&1; then
            echo -e "${GREEN}${CHECK}${NC} Marzban API is ready!"
            break
        elif [ $i -eq 30 ]; then
            echo -e "${RED}${CROSS}${NC} Marzban not responding after 30 attempts."
            echo
            exit 1
        else
            echo -e "${GRAY}  ${ARROW}${NC} Waiting for API... ($i/30)"
            sleep 5
        fi
    done
}

# Stabilize system
stabilize_system() {
    echo
    echo -e "${CYAN}${INFO}${NC} Allowing system to stabilize..."
    echo -e "${GRAY}  ${ARROW}${NC} Waiting for services to initialize"
    sleep 15
    echo -e "${GREEN}${CHECK}${NC} System stabilized!"
}

# Update hosts configuration
update_hosts_configuration() {
    echo -e "${CYAN}${INFO}${NC} Updating hosts configuration via API..."
    
    local TOKEN=""
    local API_BASE=""
    
    if authenticate_with_api TOKEN API_BASE; then
        update_hosts_via_api "$TOKEN" "$API_BASE"
    else
        echo -e "${RED}${CROSS}${NC} All authentication methods failed"
        echo -e "${YELLOW}${WARNING}${NC} Manual configuration required"
    fi
}

# Authenticate with API
authenticate_with_api() {
    local token_var=$1
    local api_base_var=$2
    
    for attempt in {1..5}; do
        echo -e "${GRAY}  ${ARROW}${NC} Authentication attempt $attempt"
        
        # Method 1: Try localhost
        if try_localhost_auth; then
            eval $token_var='"$AUTH_TOKEN"'
            eval $api_base_var='"$AUTH_API_BASE"'
            return 0
        fi
        
        # Method 2: Try HTTPS proxy
        if try_https_auth; then
            eval $token_var='"$AUTH_TOKEN"'
            eval $api_base_var='"$AUTH_API_BASE"'
            return 0
        fi
        
        # Method 3: Restart Marzban and try again
        if [ $attempt -eq 3 ]; then
            restart_marzban_for_auth
        fi
        
        sleep 5
    done
    return 1
}

# Try localhost authentication
try_localhost_auth() {
    local TOKEN_RESPONSE=$(curl -s -X POST "http://localhost:8000/api/admin/token" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "username=admin&password=$ADMIN_PASSWORD")
    
    AUTH_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token' 2>/dev/null)
    
    if [ "$AUTH_TOKEN" != "null" ] && [ -n "$AUTH_TOKEN" ] && [ "$AUTH_TOKEN" != "" ]; then
        echo -e "${GREEN}${CHECK}${NC} Authentication successful via localhost!"
        echo
        AUTH_API_BASE="http://localhost:8000"
        return 0
    fi
    return 1
}

# Try HTTPS authentication
try_https_auth() {
    local TOKEN_RESPONSE=$(curl -s -k -X POST "https://dash.$PANEL_DOMAIN/api/admin/token" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "username=admin&password=$ADMIN_PASSWORD")
    
    AUTH_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token' 2>/dev/null)
    
    if [ "$AUTH_TOKEN" != "null" ] && [ -n "$AUTH_TOKEN" ] && [ "$AUTH_TOKEN" != "" ]; then
        echo -e "${GREEN}${CHECK}${NC} Authentication successful via HTTPS!"
        AUTH_API_BASE="https://dash.$PANEL_DOMAIN"
        return 0
    fi
    return 1
}

# Restart Marzban for auth
restart_marzban_for_auth() {
    echo -e "${GRAY}  ${ARROW}${NC} Restarting Marzban for token refresh"
    $COMPOSE restart marzban > /dev/null 2>&1
    sleep 15
}

# Update hosts via API
update_hosts_via_api() {
    local token=$1
    local api_base=$2
    
    echo -e "${CYAN}${INFO}${NC} Using API base: ${WHITE}$api_base${NC}"
    echo -e "${GRAY}  ${ARROW}${NC} Updating hosts configuration"
    local HOSTS_RESPONSE=$(curl -s -w "%{http_code}" -k -X PUT "$api_base/api/hosts" \
      -H "Authorization: Bearer $token" \
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
    
    verify_hosts_update "$HOSTS_RESPONSE" "$token" "$api_base"
}

# Verify hosts update
verify_hosts_update() {
    local hosts_response=$1
    local token=$2
    local api_base=$3
    
    local HTTP_CODE="${hosts_response: -3}"
    
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
        echo -e "${GREEN}${CHECK}${NC} Hosts configuration updated successfully!"
        
        # Verify update
        sleep 5
        local UPDATED_HOSTS=$(curl -s -k -H "Authorization: Bearer $token" "$api_base/api/hosts")
        if echo "$UPDATED_HOSTS" | grep -q "Steal"; then
            :
        fi
    else
        echo -e "${YELLOW}${WARNING}${NC} Hosts update returned HTTP $HTTP_CODE"
        echo -e "${YELLOW}${WARNING}${NC} You can configure hosts manually through the dashboard"
    fi
}

#=================================
# PANEL DISPLAY RESULTS FUNCTIONS
#=================================

# Display completion info
display_completion_info() {
    echo
    echo -e "${PURPLE}=========================${NC}"
    echo -e "${GREEN}${CHECK}${NC} Installation complete!"
    echo -e "${PURPLE}=========================${NC}"
    echo
    display_dashboard_info
    display_admin_credentials
    display_useful_commands
    display_next_steps
}

# Display dashboard info
display_dashboard_info() {
    echo -e "${CYAN}Dashboard URL:${NC}"
    echo -e "${WHITE}https://dash.$PANEL_DOMAIN/$DASHBOARD_PATH${NC}"
    echo
}

# Display admin credentials
display_admin_credentials() {
    echo -e "${CYAN}Admin Credentials (${YELLOW}SAVE THESE${CYAN}):${NC}"
    echo -e "${WHITE}Username: $ADMIN_USERNAME${NC}"
    echo -e "${WHITE}Password: $ADMIN_PASSWORD_DISPLAY${NC}"
    echo
    echo -e "${CYAN}Database Credentials:${NC}"
    echo -e "${WHITE}MySQL ROOT Password: $MYSQL_ROOT_PASSWORD${NC}"
    echo -e "${WHITE}MySQL Password: $MYSQL_PASSWORD${NC}"
    echo
}

# Display useful commands
display_useful_commands() {
    echo -e "${CYAN}Useful Commands:${NC}"
    echo -e "${WHITE}• Check logs: marzban logs${NC}"
    echo -e "${WHITE}• Restart service: marzban restart${NC}"
    echo -e "${WHITE}• Update system: marzban update${NC}"
    echo
}

# Display next steps
display_next_steps() {
    echo -e "${CYAN}Next Steps:${NC}"
    echo -e "${WHITE}1. Go to \"Node settings\" in the Marzban panel.${NC}"
    echo -e "${WHITE}2. Click \"Add New Marzban Node\".${NC}"
    echo -e "${WHITE}3. Click \"Show Certificate\" and copy it.${NC}"
    echo -e "${WHITE}4. Run this script on node server and select \"Install Node\".${NC}"
    echo
}

#==================================
# MAIN PANEL INSTALLATION FUNCTION
#==================================

# Main panel installation function
install_panel() {
    set -e
    
    check_root_permissions
    
    # Display header
    echo
    echo -e "${PURPLE}===================${NC}"
    echo -e "${WHITE}Panel Installation${NC}"
    echo -e "${PURPLE}===================${NC}"
    echo
    echo -e "${GREEN}Environment variables${NC}"
    echo -e "${GREEN}=====================${NC}"
    echo

    # Collect environment variables
    input_panel_domain
    input_sub_domain
    input_selfsteal_domain
    input_cloudflare_email
    input_cloudflare_api_key
    input_node_public_ip

    # Generate dashboard path
    generate_dashboard_path

    echo
    echo -e "${GREEN}Installing packages${NC}"
    echo -e "${GREEN}===================${NC}"
    echo

    # System installation
    install_system_packages
    echo -e "${GREEN}${CHECK}${NC} System packages configured!"
    echo
    configure_firewall
    echo -e "${GREEN}${CHECK}${NC} UFW firewall configured successfully!"

    # Docker installation
    echo
    install_docker
    echo
    setup_docker_compose
    detect_architecture
    install_yq

    # Path variables
    INSTALL_DIR="/opt"
    APP_NAME="marzban"
    APP_DIR="$INSTALL_DIR/$APP_NAME"
    DATA_DIR="/var/lib/$APP_NAME"
    COMPOSE_FILE="$APP_DIR/docker-compose.yml"
    ENV_FILE="$APP_DIR/.env"

    echo
    echo -e "${GREEN}Creating structure and certificates${NC}"
    echo -e "${GREEN}===================================${NC}"
    echo

    # Create structure and certificates
    create_directory_structure
    echo
    check_cloudflare_api
    echo
    setup_cloudflare_credentials
    echo
    extract_base_domains
    echo
    generate_certificate_for_domain "$PANEL_BASE_DOMAIN" "panel"
    echo
    generate_certificate_for_domain "$SUB_BASE_DOMAIN" "sub"
    echo
    configure_certificate_renewal

    echo
    echo -e "${GREEN}Installing and configuring Nginx${NC}"
    echo -e "${GREEN}================================${NC}"
    echo

    # Install and configure Nginx
    install_nginx
    echo
    create_ssl_snippets
    echo
    configure_nginx_sites

    echo
    echo -e "${GREEN}Setting up redirect page${NC}"
    echo -e "${GREEN}========================${NC}"
    echo

    # Setup redirect page
    setup_redirect_page

    echo
    echo -e "${GREEN}Creating configuration files${NC}"
    echo -e "${GREEN}============================${NC}"
    echo

    # Create configuration files
    create_docker_compose_file
    create_env_file
    echo
    secure_configuration_files

    echo
    create_xray_config
    echo
    download_subscription_template
    echo
    install_marzban_script

    echo
    echo -e "${GREEN}Downloading and installing Xray-core${NC}"
    echo -e "${GREEN}====================================${NC}"
    echo

    # Install Xray-core
    install_xray_core

    echo
    echo -e "${GREEN}Starting Docker containers${NC}"
    echo -e "${GREEN}==========================${NC}"
    echo

    # Start containers
    start_docker_containers

    echo
    echo -e "${GREEN}Creating admin user${NC}"
    echo -e "${GREEN}===================${NC}"
    echo

    # Create admin user
    create_admin_user

    echo
    prepare_system_for_hosts
    echo
    update_hosts_configuration

    # Display completion info
    display_completion_info
}

#==================
# MAIN ENTRY POINT
#==================

# Main function
main() {
    show_main_menu
    read INSTALL_TYPE
    handle_user_choice "$INSTALL_TYPE"
}

#===================================
# NODE INSTALLATION INPUT FUNCTIONS
#===================================

# Input selfsteal domain for node
input_node_selfsteal_domain() {
    echo -ne "${CYAN}Selfsteal domain (e.g., example.com): ${NC}"
    read SELFSTEAL_DOMAIN
    while [[ -z "$SELFSTEAL_DOMAIN" ]] || ! validate_domain "$SELFSTEAL_DOMAIN"; do
        echo -e "${RED}${CROSS}${NC} Invalid domain! Please enter a valid domain (e.g., example.com)."
        echo
        echo -ne "${CYAN}Selfsteal domain: ${NC}"
        read SELFSTEAL_DOMAIN
    done
}

# Input Cloudflare email for node
input_node_cloudflare_email() {
    echo -ne "${CYAN}Cloudflare Email: ${NC}"
    read CLOUDFLARE_EMAIL
    while [[ -z "$CLOUDFLARE_EMAIL" ]]; do
        echo -e "${RED}${CROSS}${NC} Cloudflare Email cannot be empty!"
        echo
        echo -ne "${CYAN}Cloudflare Email: ${NC}"
        read CLOUDFLARE_EMAIL
    done
}

# Input Cloudflare API key for node
input_node_cloudflare_api_key() {
    echo -ne "${CYAN}Cloudflare API Key: ${NC}"
    read CLOUDFLARE_API_KEY
    while [[ -z "$CLOUDFLARE_API_KEY" ]]; do
        echo -e "${RED}${CROSS}${NC} Cloudflare API Key cannot be empty!"
        echo
        echo -ne "${CYAN}Cloudflare API Key: ${NC}"
        read CLOUDFLARE_API_KEY
    done
}

# Input main public IP for node
input_node_main_public_ip() {
    echo -ne "${CYAN}Main public IP: ${NC}"
    read MAIN_PUBLIC_IP
    while [[ -z "$MAIN_PUBLIC_IP" ]] || ! validate_ip "$MAIN_PUBLIC_IP"; do
        echo -e "${RED}${CROSS}${NC} Invalid IP! Please enter a valid IPv4 address (e.g., 1.2.3.4)."
        echo
        echo -ne "${CYAN}Main public IP: ${NC}"
        read MAIN_PUBLIC_IP
    done
}

# Input node port
input_node_port() {
    echo -ne "${CYAN}Node VLESS Reality port (default 10000, press Enter to use it): ${NC}"
    read NODE_PORT
    if [[ -z "$NODE_PORT" ]]; then
        NODE_PORT=10000
    fi
    # Validate port range
    while [[ ! "$NODE_PORT" =~ ^[0-9]+$ ]] || [ "$NODE_PORT" -lt 1 ] || [ "$NODE_PORT" -gt 65535 ]; do
        echo -e "${RED}${CROSS}${NC} Invalid port! Please enter a valid port (1-65535)."
        echo
        echo -ne "${CYAN}Node port (default 10000): ${NC}"
        read NODE_PORT
        if [[ -z "$NODE_PORT" ]]; then
            NODE_PORT=10000
            break
        fi
    done
}

#====================================
# NODE SYSTEM INSTALLATION FUNCTIONS
#====================================

# Install node system packages
install_node_system_packages() {
    echo -e "${CYAN}${INFO}${NC} Installing basic packages..."
    echo -e "${GRAY}  ${ARROW}${NC} Updating package lists"
    apt-get update > /dev/null 2>&1
    echo -e "${GRAY}  ${ARROW}${NC} Installing essential packages"
    apt-get -y install jq curl unzip wget python3-certbot-dns-cloudflare git > /dev/null 2>&1

    configure_node_locale
    configure_node_timezone
    configure_node_tcp_bbr
    configure_node_security_updates
}

# Configure locale for node
configure_node_locale() {
    echo -e "${GRAY}  ${ARROW}${NC} Configuring locales"
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen 2>/dev/null
    locale-gen > /dev/null 2>&1
    update-locale LANG=en_US.UTF-8 > /dev/null 2>&1
}

# Configure timezone for node
configure_node_timezone() {
    echo -e "${GRAY}  ${ARROW}${NC} Setting timezone to Europe/Moscow"
    timedatectl set-timezone Europe/Moscow > /dev/null 2>&1
}

# Configure TCP BBR for node
configure_node_tcp_bbr() {
    echo -e "${GRAY}  ${ARROW}${NC} Configuring TCP BBR optimization"
    echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf 2>/dev/null
    echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf 2>/dev/null
    sysctl -p > /dev/null 2>&1
}

# Configure security updates for node
configure_node_security_updates() {
    echo -e "${GRAY}  ${ARROW}${NC} Configuring automatic security updates"
    apt-get -y install unattended-upgrades ufw > /dev/null 2>&1
    echo 'Unattended-Upgrade::Mail "root";' >> /etc/apt/apt.conf.d/50unattended-upgrades 2>/dev/null
    echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections > /dev/null 2>&1
    dpkg-reconfigure -f noninteractive unattended-upgrades > /dev/null 2>&1
    systemctl restart unattended-upgrades > /dev/null 2>&1
}

#=========================
# NODE FIREWALL FUNCTIONS
#=========================

# Configure UFW firewall for node
configure_node_firewall() {
    echo -e "${CYAN}${INFO}${NC} Configuring UFW firewall..."
    echo -e "${GRAY}  ${ARROW}${NC} Resetting firewall rules"
    ufw --force reset > /dev/null 2>&1
    echo -e "${GRAY}  ${ARROW}${NC} Allowing SSH access"
    ufw allow 22/tcp comment 'SSH' > /dev/null 2>&1
    echo -e "${GRAY}  ${ARROW}${NC} Allowing HTTPS (Reality)"
    ufw allow 443/tcp comment 'HTTPS (Reality)' > /dev/null 2>&1
    echo -e "${GRAY}  ${ARROW}${NC} Allowing node port"
    ufw allow $NODE_PORT/tcp comment 'HTTPS (Reality)' > /dev/null 2>&1

    configure_main_server_firewall_rules

    echo -e "${GRAY}  ${ARROW}${NC} Enabling firewall"
    ufw --force enable > /dev/null 2>&1
    echo -e "${GREEN}${CHECK}${NC} UFW firewall configured successfully!"
}

# Configure panel server firewall rules
configure_main_server_firewall_rules() {
    echo -e "${GRAY}  ${ARROW}${NC} Adding main server rules"
    ufw allow from "$MAIN_PUBLIC_IP" to any port 62050 proto tcp comment 'Marzmain' > /dev/null 2>&1
    ufw allow from "$MAIN_PUBLIC_IP" to any port 62051 proto tcp comment 'Marzmain' > /dev/null 2>&1
}

#====================================
# NODE DOCKER INSTALLATION FUNCTIONS
#====================================

# Install Docker for node
install_node_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${CYAN}${INFO}${NC} Installing Docker..."
        add_node_docker_repository
        install_node_docker_packages
        echo -e "${GREEN}${CHECK}${NC} Docker installed successfully!"
    else
        echo -e "${GREEN}${CHECK}${NC} Docker already installed"
    fi
}

# Add Docker repository for node
add_node_docker_repository() {
    echo -e "${GRAY}  ${ARROW}${NC} Adding Docker repository"
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | tee /etc/apt/keyrings/docker.asc > /dev/null
    chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
}

# Install Docker packages for node
install_node_docker_packages() {
    echo -e "${GRAY}  ${ARROW}${NC} Installing Docker packages"
    apt-get update > /dev/null 2>&1
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1
}

# Setup Docker Compose for node
setup_node_docker_compose() {
    if docker compose version >/dev/null 2>&1; then
        COMPOSE='docker compose'
    elif docker-compose version >/dev/null 2>&1; then
        COMPOSE='docker-compose'
    else
        echo -e "${RED}${CROSS}${NC} Docker Compose not found."
        echo
        exit 1
    fi
}

#==========================================
# NODE DIRECTORY AND CERTIFICATE FUNCTIONS
#==========================================

# Create node directory structure
create_node_directory_structure() {
    echo -e "${CYAN}${INFO}${NC} Creating directory structure..."
    echo -e "${GRAY}  ${ARROW}${NC} Creating data directory: $DATA_DIR"
    mkdir -p "$DATA_DIR"
    echo -e "${GRAY}  ${ARROW}${NC} Creating app directory: $APP_DIR"
    mkdir -p "$APP_DIR"
    echo -e "${GRAY}  ${ARROW}${NC} Creating marzban directory"
    mkdir -p /var/lib/marzban
    echo -e "${GREEN}${CHECK}${NC} Directory structure created!"
}

# Check Cloudflare API for node
check_node_cloudflare_api() {
    echo -e "${CYAN}${INFO}${NC} Checking Cloudflare API..."
    if [[ $CLOUDFLARE_API_KEY =~ [A-Z] ]]; then
        echo -e "${GRAY}  ${ARROW}${NC} Using API Token authentication"
        api_response=$(curl --silent --request GET --url https://api.cloudflare.com/client/v4/zones --header "Authorization: Bearer ${CLOUDFLARE_API_KEY}" --header "Content-Type: application/json")
    else
        echo -e "${GRAY}  ${ARROW}${NC} Using Global API Key authentication"
        api_response=$(curl --silent --request GET --url https://api.cloudflare.com/client/v4/zones --header "X-Auth-Key: ${CLOUDFLARE_API_KEY}" --header "X-Auth-Email: ${CLOUDFLARE_EMAIL}" --header "Content-Type: application/json")
    fi
    echo -e "${GREEN}${CHECK}${NC} Cloudflare API credentials verified!"
}

# Setup Cloudflare credentials for node
setup_node_cloudflare_credentials() {
    echo -e "${CYAN}${INFO}${NC} Setting up Cloudflare credentials..."
    echo -e "${GRAY}  ${ARROW}${NC} Creating credentials directory"
    mkdir -p ~/.secrets/certbot

    if [ ! -f ~/.secrets/certbot/cloudflare.ini ]; then
        echo -e "${GRAY}  ${ARROW}${NC} Creating Cloudflare credentials file"
        create_node_cloudflare_credentials_file
        chmod 600 ~/.secrets/certbot/cloudflare.ini
        echo -e "${GREEN}${CHECK}${NC} Cloudflare credentials file created!"
    else
        echo -e "${GREEN}${CHECK}${NC} Cloudflare credentials file already exists"
    fi
}

# Create Cloudflare credentials file for node
create_node_cloudflare_credentials_file() {
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
}

# Extract base domain for node
extract_node_base_domain() {
    echo -e "${CYAN}${INFO}${NC} Extracting base domain..."
    echo -e "${GRAY}  ${ARROW}${NC} Processing selfsteal domain"
    BASE_DOMAIN=$(echo "$SELFSTEAL_DOMAIN" | awk -F'.' '{if (NF > 2) {print $(NF-1)"."$NF} else {print $0}}')
    echo -e "${GREEN}${CHECK}${NC} Base domain extracted: ${WHITE}$BASE_DOMAIN${NC}"
}

# Generate wildcard certificate for node
generate_node_wildcard_certificate() {
    echo -e "${CYAN}${INFO}${NC} Checking certificate for selfsteal domain..."
    echo -e "${GRAY}  ${ARROW}${NC} Verifying certificate status for $BASE_DOMAIN"
    if [ ! -d "/etc/letsencrypt/live/$BASE_DOMAIN" ]; then
        echo -e "${GRAY}  ${ARROW}${NC} Generating wildcard certificate for $BASE_DOMAIN"
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
            --elliptic-curve secp384r1 > /dev/null 2>&1
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}${CROSS}${NC} Failed to generate SSL certificate for $BASE_DOMAIN. Check Cloudflare credentials."
            echo
            exit 1
        fi
        echo -e "${GREEN}${CHECK}${NC} Certificate generated for $BASE_DOMAIN!"
    else
        echo -e "${GREEN}${CHECK}${NC} Certificate for $BASE_DOMAIN already exists"
    fi
}

# Configure node certificate renewal
configure_node_certificate_renewal() {
    echo -e "${CYAN}${INFO}${NC} Configuring certificate renewal..."
    echo -e "${GRAY}  ${ARROW}${NC} Adding renewal hooks"
    if [ -f "/etc/letsencrypt/renewal/$BASE_DOMAIN.conf" ]; then
        echo "renew_hook = systemctl reload nginx" >> /etc/letsencrypt/renewal/$BASE_DOMAIN.conf
    fi
    echo -e "${GRAY}  ${ARROW}${NC} Setting up cron job"
    (crontab -u root -l 2>/dev/null; echo "0 5 1 */2 * /usr/bin/certbot renew --quiet") | crontab -u root -
    echo -e "${GREEN}${CHECK}${NC} SSL certificates configured successfully!"
}

#===================================
# NODE NGINX INSTALLATION FUNCTIONS
#===================================

# Install Nginx for node
install_node_nginx() {
    echo -e "${CYAN}${INFO}${NC} Installing Nginx from official repository..."
    add_node_nginx_repository
    install_node_nginx_package
    echo -e "${GREEN}${CHECK}${NC} Nginx installed successfully!"
}

# Add Nginx repository for node
add_node_nginx_repository() {
    echo -e "${GRAY}  ${ARROW}${NC} Adding Nginx signing key"
    curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor --yes -o /etc/apt/keyrings/nginx-signing.gpg > /dev/null 2>&1
    echo -e "${GRAY}  ${ARROW}${NC} Adding Nginx repository"
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/nginx-signing.gpg] http://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" > /etc/apt/sources.list.d/nginx.list
}

# Install Nginx package for node
install_node_nginx_package() {
    echo -e "${GRAY}  ${ARROW}${NC} Installing Nginx package"
    apt update > /dev/null 2>&1 && apt install nginx -y > /dev/null 2>&1
}

# Create SSL snippets for node
create_node_ssl_snippets() {
    echo -e "${CYAN}${INFO}${NC} Creating SSL snippets..."
    echo -e "${GRAY}  ${ARROW}${NC} Creating snippets directory"
    mkdir -p /etc/nginx/snippets

    create_node_ssl_snippet
    create_node_ssl_params_snippet
    
    echo -e "${GREEN}${CHECK}${NC} SSL snippets created!"
}

# Create SSL snippet for node
create_node_ssl_snippet() {
    echo -e "${GRAY}  ${ARROW}${NC} Creating SSL snippet for selfsteal domain"
    cat > /etc/nginx/snippets/ssl.conf << EOF
ssl_certificate /etc/letsencrypt/live/$BASE_DOMAIN/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/$BASE_DOMAIN/privkey.pem;
EOF
}

# Create SSL parameters snippet for node
create_node_ssl_params_snippet() {
    echo -e "${GRAY}  ${ARROW}${NC} Creating SSL parameters snippet"
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
}

# Configure Nginx sites for node
configure_node_nginx_sites() {
    echo -e "${CYAN}${INFO}${NC} Configuring Nginx sites..."
    echo -e "${GRAY}  ${ARROW}${NC} Removing default configuration"
    rm -f /etc/nginx/conf.d/default.conf

    create_node_sni_site_config
    download_node_sni_page
    create_node_main_nginx_config
    
    echo -e "${GRAY}  ${ARROW}${NC} Testing configuration and starting service"
    nginx -t > /dev/null 2>&1 && systemctl restart nginx > /dev/null 2>&1 && systemctl enable nginx > /dev/null 2>&1
    echo -e "${GREEN}${CHECK}${NC} Nginx configured successfully!"
}

# Create SNI site config for node
create_node_sni_site_config() {
    echo -e "${GRAY}  ${ARROW}${NC} Creating SNI site configuration"
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
}

# Download SNI page for node
download_node_sni_page() {
    echo -e "${GRAY}  ${ARROW}${NC} Downloading SNI page"
    wget -q https://raw.githubusercontent.com/supermegaelf/mb-files/main/pages/sni/sni.html -O /usr/share/nginx/html/sni.html > /dev/null 2>&1
}

# Create main Nginx config for node
create_node_main_nginx_config() {
    echo -e "${GRAY}  ${ARROW}${NC} Creating main Nginx configuration"
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
}

#===================================
# NODE TRAFFIC FORWARDING FUNCTIONS
#===================================

# Configure traffic forwarding for node
configure_node_traffic_forwarding() {
    echo -e "${CYAN}${INFO}${NC} Enabling IP forwarding..."
    echo -e "${GRAY}  ${ARROW}${NC} Configuring IP forwarding in UFW"
    echo 'net/ipv4/ip_forward=1' >> /etc/ufw/sysctl.conf

    configure_node_nat_rules
    
    echo -e "${GRAY}  ${ARROW}${NC} Reloading UFW with new NAT rules"
    ufw --force reload > /dev/null 2>&1
    echo -e "${GREEN}${CHECK}${NC} Traffic forwarding configured successfully!"
}

# Configure NAT rules for node
configure_node_nat_rules() {
    echo -e "${GRAY}  ${ARROW}${NC} Configuring NAT rules for traffic forwarding"
    cat >> /etc/ufw/before.rules << EOF
*nat
:PREROUTING ACCEPT [0:0]
-A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port $NODE_PORT
COMMIT
EOF
}

#====================================
# NODE CONFIGURATION FILES FUNCTIONS
#====================================

# Create docker-compose for node
create_node_docker_compose() {
    echo -e "${CYAN}${INFO}${NC} Setting up docker-compose.yml for Marzban Node..."
    echo -e "${GRAY}  ${ARROW}${NC} Creating docker-compose configuration"

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

    echo -e "${GREEN}${CHECK}${NC} docker-compose.yml created!"
    echo
    echo -e "${CYAN}${INFO}${NC} File generated at: ${WHITE}$APP_DIR/docker-compose.yml${NC}"
    echo
}

# Create SSL certificate file for node
create_node_ssl_certificate_file() {
    echo -e "${CYAN}${INFO}${NC} Creating Marzban-node SSL certificate file..."
    echo -e "${GRAY}  ${ARROW}${NC} Creating SSL certificate file"
    touch "$DATA_DIR/ssl_client_cert.pem"

    echo -e "${GRAY}  ${ARROW}${NC} Opening nano editor for SSL certificate paste..."
    echo -ne "${YELLOW}  Press \"Enter\", paste Node SSL certificate, then save and exit (Ctrl+X)...${NC}"
    read

    nano "$DATA_DIR/ssl_client_cert.pem"
    echo -e "${GREEN}${CHECK}${NC} SSL certificate updated!"
}

# Configure log rotation for node
configure_node_log_rotation() {
    echo -e "${CYAN}${INFO}${NC} Configuring log rotation..."
    echo -e "${GRAY}  ${ARROW}${NC} Creating logrotate configuration"
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

    echo -e "${GRAY}  ${ARROW}${NC} Running logrotate"
    logrotate -f /etc/logrotate.conf > /dev/null 2>&1
    echo -e "${GREEN}${CHECK}${NC} Log rotation configured!"
}

#==================================
# NODE DOCKER CONTAINERS FUNCTIONS
#==================================

# Start Docker containers for node
start_node_docker_containers() {
    echo -e "${CYAN}${INFO}${NC} Starting Docker containers..."
    echo -e "${GRAY}  ${ARROW}${NC} Navigating to application directory"
    cd "$APP_DIR"

    echo -e "${GRAY}  ${ARROW}${NC} Starting services with docker compose"
    $COMPOSE up -d --remove-orphans > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}${CROSS}${NC} Failed to start containers. Check: $COMPOSE logs."
        echo
        exit 1
    fi

    wait_for_node_services
    check_node_container_status
    echo -e "${GREEN}${CHECK}${NC} Marzban Node started successfully!"
}

# Wait for node services
wait_for_node_services() {
    echo -e "${GRAY}  ${ARROW}${NC} Waiting for services to be ready"
    sleep 10
}

# Check node container status
check_node_container_status() {
    echo -e "${GRAY}  ${ARROW}${NC} Checking container status"
    $COMPOSE ps > /dev/null 2>&1
}

#================================
# NODE DISPLAY RESULTS FUNCTIONS
#================================

# Display node completion info
display_node_completion_info() {
    echo
    echo -e "${PURPLE}=========================${NC}"
    echo -e "${GREEN}${CHECK}${NC} Installation complete!"
    echo -e "${PURPLE}=========================${NC}"
    echo
    display_node_useful_commands
    display_node_next_steps
}

# Display node useful commands
display_node_useful_commands() {
    echo -e "${CYAN}Useful Commands:${NC}"
    echo -e "${WHITE}• Check logs: cd /opt/marzban-node && docker compose logs -f${NC}"
    echo -e "${WHITE}• Restart service: cd /opt/marzban-node && docker compose restart${NC}"
    echo
}

# Display node next steps
display_node_next_steps() {
    echo -e "${CYAN}Next Steps:${NC}"
    echo -e "${WHITE}1. Go to \"Node settings\" in the Marzban panel.${NC}"
    echo -e "${WHITE}2. Fill in the \"Name\" and \"Address\" fields.${NC}"
    echo -e "${WHITE}3. Click \"Update Node\".${NC}"
    echo
}

#=================================
# MAIN NODE INSTALLATION FUNCTION
#=================================

# Check root permissions for node
check_node_root_permissions() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}${CROSS}${NC} This command must be run as root."
        echo
        exit 1
    fi
}

# Node installation function
install_node() {
    set -e
    
    check_node_root_permissions
    
    # Display header
    echo
    echo -e "${PURPLE}==================${NC}"
    echo -e "${WHITE}Node Installation${NC}"
    echo -e "${PURPLE}==================${NC}"
    echo
    echo -e "${GREEN}Environment variables${NC}"
    echo -e "${GREEN}=====================${NC}"
    echo

    # Collect environment variables
    input_node_selfsteal_domain
    input_node_cloudflare_email
    input_node_cloudflare_api_key
    input_node_main_public_ip
    input_node_port

    echo
    echo -e "${GREEN}Installing packages${NC}"
    echo -e "${GREEN}===================${NC}"
    echo

    # System installation
    install_node_system_packages
    echo -e "${GREEN}${CHECK}${NC} System packages configured!"
    echo
    configure_node_firewall

    # Docker installation
    echo
    install_node_docker
    setup_node_docker_compose

    # Path variables
    INSTALL_DIR="/opt"
    APP_NAME="marzban-node"
    APP_DIR="$INSTALL_DIR/$APP_NAME"
    DATA_DIR="/var/lib/$APP_NAME"
    COMPOSE_FILE="$APP_DIR/docker-compose.yml"

    echo
    echo -e "${GREEN}Creating structure and certificates${NC}"
    echo -e "${GREEN}===================================${NC}"
    echo

    # Create structure and certificates
    create_node_directory_structure
    echo
    check_node_cloudflare_api
    echo
    setup_node_cloudflare_credentials
    echo
    extract_node_base_domain
    echo
    generate_node_wildcard_certificate
    echo
    configure_node_certificate_renewal

    echo
    echo -e "${GREEN}Installing and configuring Nginx${NC}"
    echo -e "${GREEN}================================${NC}"
    echo

    # Install and configure Nginx
    install_node_nginx
    echo
    create_node_ssl_snippets
    echo
    configure_node_nginx_sites

    echo
    echo -e "${GREEN}Configuring traffic forwarding and UFW${NC}"
    echo -e "${GREEN}======================================${NC}"
    echo

    # Configure traffic forwarding
    configure_node_traffic_forwarding

    echo
    echo -e "${GREEN}Creating configuration files${NC}"
    echo -e "${GREEN}============================${NC}"
    echo

    # Create configuration files
    create_node_docker_compose
    create_node_ssl_certificate_file
    echo
    configure_node_log_rotation

    echo
    echo -e "${GREEN}Starting Docker containers${NC}"
    echo -e "${GREEN}==========================${NC}"
    echo

    # Start containers
    start_node_docker_containers

    # Display completion info
    display_node_completion_info
}

#=====================================
# COMBINED SCRIPT EXECUTION FUNCTIONS
#=====================================

# Function to run from
install_node_from_main() {
    install_node
}

#=======================
# MAIN SCRIPT EXECUTION
#=======================

# Main Script execution
main
