#!/bin/bash

#==============================
# MARZBAN MONITORING MANAGER
#==============================

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

# Global variables
PANEL_DOMAIN=""
MARZBAN_USERNAME=""
MARZBAN_PASSWORD=""
EXTERNAL_NODES=()

#=======================
# VALIDATION FUNCTIONS
#=======================

# Check root privileges
check_root_privileges() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}${CROSS}${NC} This script must be run as root"
        echo
        exit 1
    fi
}

# Check monitoring status
check_monitoring_status() {
    local monitoring_installed=false
    local node_exporter_installed=false
    
    if [ -d "/opt/marzban-monitoring" ] && [ -f "/opt/marzban-monitoring/prometheus/prometheus.yml" ]; then
        monitoring_installed=true
    fi
    
    if [ -f "/usr/local/bin/node_exporter" ] && systemctl is-active --quiet node_exporter; then
        node_exporter_installed=true
    fi
    
    echo "$monitoring_installed,$node_exporter_installed"
}

#======================
# STATUS FUNCTIONS
#======================

# Show current status
show_status() {
    echo
    echo -e "${PURPLE}=========================${NC}"
    echo -e "${NC}Current Monitoring Status${NC}"
    echo -e "${PURPLE}=========================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Checking monitoring installation status..."
    echo -e "${GRAY}  ${ARROW}${NC} Verifying monitoring directory structure"
    echo -e "${GRAY}  ${ARROW}${NC} Checking Node Exporter service status"
    echo -e "${GRAY}  ${ARROW}${NC} Validating Docker containers"
    
    local status=$(check_monitoring_status)
    local monitoring_installed=$(echo $status | cut -d',' -f1)
    local node_exporter_installed=$(echo $status | cut -d',' -f2)
    
    if [ "$monitoring_installed" != "true" ]; then
        echo -e "${RED}${CROSS}${NC} Panel monitoring is not installed"
        echo
        return
    fi
    
    echo -e "${GREEN}${CHECK}${NC} Status check completed!"
    echo

    echo -e "${GREEN}Service Status${NC}"
    echo -e "${GREEN}==============${NC}"
    echo

    # Check monitoring installation
    if [ "$monitoring_installed" = "true" ]; then
        echo -e "${GREEN}${CHECK}${NC} Panel monitoring is installed"
    else
        echo -e "${RED}${CROSS}${NC} Panel monitoring is not installed"
    fi
    
    # Check Node Exporter
    if [ "$node_exporter_installed" = "true" ]; then
        echo -e "${GREEN}${CHECK}${NC} Node Exporter is running"
    else
        echo -e "${RED}${CROSS}${NC} Node Exporter is not running"
    fi
    
    # Check Docker containers
    if docker ps | grep -q "grafana\|prometheus\|marzban-exporter"; then
        echo -e "${GREEN}${CHECK}${NC} Monitoring containers are running"
    else
        echo -e "${RED}${CROSS}${NC} Monitoring containers are not running"
    fi
    
    # Check Marzban container
    if docker ps | grep -q "marzban"; then
        echo -e "${GREEN}${CHECK}${NC} Marzban container is running"
    else
        echo -e "${RED}${CROSS}${NC} Marzban container is not running"
    fi
    
    # Check ports
    if ss -tlnp | grep -q 3000; then
        echo -e "${GREEN}${CHECK}${NC} Port 3000 (Grafana) is listening"
    else
        echo -e "${YELLOW}${WARNING}${NC} Port 3000 (Grafana) is not listening"
    fi

    if ss -tlnp | grep -q 9090; then
        echo -e "${GREEN}${CHECK}${NC} Port 9090 (Prometheus) is listening"
    else
        echo -e "${YELLOW}${WARNING}${NC} Port 9090 (Prometheus) is not listening"
    fi

    if ss -tlnp | grep -q 8080; then
        echo -e "${GREEN}${CHECK}${NC} Port 8080 (Marzban Exporter) is listening"
    else
        echo -e "${YELLOW}${WARNING}${NC} Port 8080 (Marzban Exporter) is not listening"
    fi
    
    # Show current targets
    if [ -f "/opt/marzban-monitoring/prometheus/prometheus.yml" ]; then
        echo

        echo -e "${GREEN}Target Configuration${NC}"
        echo -e "${GREEN}====================${NC}"
        echo
        
        # Panel targets
        echo -e "${CYAN}Panel targets:${NC}"
        echo "- Prometheus (127.0.0.1:9090)"
        echo "- Node Exporter (127.0.0.1:9100)"
        echo "- Marzban Exporter (127.0.0.1:8080)"
        
        # External nodes
        local external_nodes=$(grep -A 20 "job_name: 'node-exporter-nodes'" /opt/marzban-monitoring/prometheus/prometheus.yml 2>/dev/null | grep -E "^\s*-\s" | grep -v "targets:" | wc -l)
        if [ "$external_nodes" -gt 0 ]; then
            echo
            echo -e "${CYAN}External nodes:${NC}"
            grep -A 20 "job_name: 'node-exporter-nodes'" /opt/marzban-monitoring/prometheus/prometheus.yml | grep -E "^\s*-\s" | grep -v "targets:" | sed 's/^[[:space:]]*-[[:space:]]*/- /' | sed "s/'//g"
        else
            echo
            echo -e "${YELLOW}No external nodes configured${NC}"
        fi
    fi
    echo
}

#============================
# INPUT VALIDATION FUNCTIONS
#============================

# Input panel domain
input_panel_domain() {
    while true; do
        echo -ne "${CYAN}Panel domain (e.g., dash.example.com): ${NC}"
        read PANEL_DOMAIN
        if [[ -n "$PANEL_DOMAIN" ]]; then
            break
        fi
        echo -e "${RED}${CROSS}${NC} Panel domain cannot be empty!"
    done
}

# Input admin credentials
input_admin_credentials() {
    echo -ne "${CYAN}Panel admin username: ${NC}"
    read MARZBAN_USERNAME
    MARZBAN_USERNAME=${MARZBAN_USERNAME:-admin}
    
    while true; do
        echo -ne "${CYAN}Panel admin password: ${NC}"
        read MARZBAN_PASSWORD
        if [[ -n "$MARZBAN_PASSWORD" ]]; then
            break
        fi
        echo -e "${RED}${CROSS}${NC} Password cannot be empty!"
    done
}

#=============================
# NODE EXPORTER FUNCTIONS
#=============================

# Install Node Exporter
install_node_exporter() {
    echo
    echo -e "${GREEN}Node Exporter Installation${NC}"
    echo -e "${GREEN}==========================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Installing Node Exporter service..."
    echo -e "${GRAY}  ${ARROW}${NC} Checking existing installation"

    # Check if Node Exporter is already installed and running
    if [ -f "/usr/local/bin/node_exporter" ] && systemctl is-active --quiet node_exporter; then
        echo -e "${GRAY}  ${ARROW}${NC} Found existing installation"
        echo -e "${GREEN}${CHECK}${NC} Node Exporter is already installed and running!"
        return
    fi

    echo -e "${GRAY}  ${ARROW}${NC} Stopping existing services"
    # Stop Node Exporter if it's running
    if systemctl is-active --quiet node_exporter; then
        systemctl stop node_exporter > /dev/null 2>&1
    fi

    echo -e "${GRAY}  ${ARROW}${NC} Downloading Node Exporter v1.9.1"
    echo -e "${GRAY}  ${ARROW}${NC} Extracting binary files"
    echo -e "${GRAY}  ${ARROW}${NC} Installing to /usr/local/bin"
    # Download and install Node Exporter
    wget -q https://github.com/prometheus/node_exporter/releases/download/v1.9.1/node_exporter-1.9.1.linux-amd64.tar.gz > /dev/null 2>&1
    tar xvf node_exporter-1.9.1.linux-amd64.tar.gz > /dev/null 2>&1
    cp node_exporter-1.9.1.linux-amd64/node_exporter /usr/local/bin/
    rm -rf node_exporter-1.9.1.linux-amd64*

    echo -e "${GRAY}  ${ARROW}${NC} Creating system user and service"
    echo -e "${GRAY}  ${ARROW}${NC} Setting file permissions"
    # Create user and service
    useradd --no-create-home --shell /bin/false node_exporter 2>/dev/null || true
    chown node_exporter:node_exporter /usr/local/bin/node_exporter

    cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${GRAY}  ${ARROW}${NC} Enabling and starting service"
    # Start Node Exporter
    systemctl daemon-reload > /dev/null 2>&1
    systemctl enable node_exporter > /dev/null 2>&1
    systemctl start node_exporter > /dev/null 2>&1
    echo -e "${GREEN}${CHECK}${NC} Node Exporter installation completed successfully!"
}

#==============================
# MONITORING SETUP FUNCTIONS
#==============================

# Setup monitoring structure
setup_monitoring_structure() {
    echo
    echo -e "${GREEN}Monitoring Structure Setup${NC}"
    echo -e "${GREEN}==========================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Setting up monitoring infrastructure..."
    echo -e "${GRAY}  ${ARROW}${NC} Checking system dependencies"
    
    # Check and install git if needed
    if ! command -v git &> /dev/null; then
        echo -e "${GRAY}  ${ARROW}${NC} Installing git package"
        apt update > /dev/null 2>&1
        apt install -y git > /dev/null 2>&1
    fi

    echo -e "${GRAY}  ${ARROW}${NC} Creating monitoring directory structure"
    echo -e "${GRAY}  ${ARROW}${NC} Setting up Prometheus configuration"
    # Create monitoring structure
    mkdir -p /opt/marzban-monitoring
    cd /opt/marzban-monitoring

    echo -e "${GRAY}  ${ARROW}${NC} Cloning marzban-exporter repository"
    # Clone marzban-exporter
    if [ -d "marzban-exporter" ]; then
        rm -rf marzban-exporter
    fi
    git clone https://github.com/kutovoys/marzban-exporter.git > /dev/null 2>&1

    echo -e "${GRAY}  ${ARROW}${NC} Generating configuration files"
    # Create Prometheus configuration
    mkdir -p prometheus
    cat > prometheus/prometheus.yml << PROM_EOF
global:
  scrape_interval: 15s
  scrape_timeout: 10s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['127.0.0.1:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['127.0.0.1:9100']
    scrape_interval: 15s
    scrape_timeout: 5s

  - job_name: 'marzban-exporter'
    static_configs:
      - targets: ['127.0.0.1:8080']
    scrape_interval: 30s
    scrape_timeout: 10s
PROM_EOF

    echo -e "${GREEN}${CHECK}${NC} Monitoring structure setup completed!"
}

# Create environment configuration
create_environment_config() {
    echo
    echo -e "${CYAN}${INFO}${NC} Creating environment configuration..."
    echo -e "${GRAY}  ${ARROW}${NC} Generating marzban-exporter environment file"
    echo -e "${GRAY}  ${ARROW}${NC} Setting up authentication parameters"
    echo -e "${GRAY}  ${ARROW}${NC} Configuring API endpoints"
    
    # Create environment file for marzban-exporter
    cat > marzban-exporter/.env << ENV_EOF
MARZBAN_BASE_URL=https://${PANEL_DOMAIN}
MARZBAN_USERNAME=${MARZBAN_USERNAME}
MARZBAN_PASSWORD=${MARZBAN_PASSWORD}
ENV_EOF

    # Also create command line args file
    cat > marzban-exporter/config.env << CONFIG_EOF
MARZBAN_BASE_URL=https://${PANEL_DOMAIN}
MARZBAN_USERNAME=${MARZBAN_USERNAME}  
MARZBAN_PASSWORD=${MARZBAN_PASSWORD}
CONFIG_EOF

    echo -e "${GREEN}${CHECK}${NC} Environment configuration created successfully!"
}

# Create Docker Compose configuration
create_docker_compose() {
    echo
    echo -e "${CYAN}${INFO}${NC} Creating Docker Compose configuration..."
    echo -e "${GRAY}  ${ARROW}${NC} Setting up service definitions"
    echo -e "${GRAY}  ${ARROW}${NC} Configuring network settings"
    echo -e "${GRAY}  ${ARROW}${NC} Setting up volume mounts"
    echo -e "${GRAY}  ${ARROW}${NC} Configuring logging parameters"
    
    # Create Docker Compose for monitoring
    cat > docker-compose.yml << COMPOSE_EOF
services:
  marzban-exporter:
    build: ./marzban-exporter
    container_name: marzban-exporter
    restart: unless-stopped
    command: 
      - "/marzban-exporter"
      - "--marzban-base-url=https://${PANEL_DOMAIN}"
      - "--marzban-username=${MARZBAN_USERNAME}"
      - "--marzban-password=${MARZBAN_PASSWORD}"
      - "--metrics-port=8080"
    ports:
      - "127.0.0.1:8080:8080"
    networks:
      - monitoring
    logging:
      driver: 'json-file'
      options:
        max-size: '30m'
        max-file: '5'

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    network_mode: host
    volumes:
      - grafana-storage:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
      - ./grafana/dashboards:/var/lib/grafana/dashboards
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    logging:
      driver: 'json-file'
      options:
        max-size: '30m'
        max-file: '5'

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - prom_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
      - '--web.listen-address=0.0.0.0:9090'
    logging:
      driver: 'json-file'
      options:
        max-size: '30m'
        max-file: '5'

volumes:
  grafana-storage:
  prom_data:

networks:
  monitoring:
    driver: bridge
COMPOSE_EOF

    echo -e "${GREEN}${CHECK}${NC} Docker Compose configuration created successfully!"
}

# Setup Grafana provisioning
setup_grafana_provisioning() {
    echo
    echo -e "${CYAN}${INFO}${NC} Setting up Grafana provisioning..."
    echo -e "${GRAY}  ${ARROW}${NC} Creating directory structure"
    echo -e "${GRAY}  ${ARROW}${NC} Configuring Prometheus datasource"
    echo -e "${GRAY}  ${ARROW}${NC} Setting up dashboard provider"
    
    mkdir -p grafana/provisioning/datasources
    mkdir -p grafana/provisioning/dashboards
    mkdir -p grafana/dashboards
    
    # Prometheus datasource
    cat > grafana/provisioning/datasources/prometheus.yml << DATASOURCE_EOF
apiVersion: 1

datasources:
  - name: prometheus
    type: prometheus
    access: proxy
    url: http://127.0.0.1:9090
    isDefault: true
DATASOURCE_EOF

    # Dashboard provider
    cat > grafana/provisioning/dashboards/dashboard.yml << DASHBOARD_EOF
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    options:
      path: /var/lib/grafana/dashboards
DASHBOARD_EOF

    echo -e "${GREEN}${CHECK}${NC} Grafana provisioning setup completed!"
}

#==========================
# DOMAIN SETUP FUNCTIONS
#==========================

# Configure domains
configure_domains() {
    echo
    echo -e "${GREEN}Domain Configuration${NC}"
    echo -e "${GREEN}====================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Configuring monitoring domains..."
    echo -e "${GRAY}  ${ARROW}${NC} Generating domain names from panel domain"
    echo -e "${GRAY}  ${ARROW}${NC} Creating Nginx configurations"
    echo -e "${GRAY}  ${ARROW}${NC} Setting up reverse proxy rules"

    # Auto-generate domains from base domain
    BASE_DOMAIN=$(echo "$PANEL_DOMAIN" | awk -F'.' '{if (NF > 2) {print $(NF-1)"."$NF} else {print $0}}')
    GRAFANA_DOMAIN="grafana.$BASE_DOMAIN"
    PROMETHEUS_DOMAIN="prometheus.$BASE_DOMAIN"

    # Create Grafana Nginx config
    cat > /etc/nginx/conf.d/grafana-monitoring.conf << GRAFANA_NGINX_EOF
server {
    server_name $GRAFANA_DOMAIN;

    listen 443 ssl;
    http2 on;

    # Grafana Proxy
    location / {
        proxy_redirect off;
        proxy_http_version 1.1;
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        
        # Timeouts
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }

    # Grafana API
    location /api/ {
        proxy_redirect off;
        proxy_http_version 1.1;
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    include /etc/nginx/snippets/ssl.conf;
    include /etc/nginx/snippets/ssl-params.conf;
}
GRAFANA_NGINX_EOF

    # Create Prometheus Nginx config
    cat > /etc/nginx/conf.d/prometheus-monitoring.conf << PROMETHEUS_NGINX_EOF
server {
    server_name $PROMETHEUS_DOMAIN;

    listen 443 ssl;
    http2 on;

    # Prometheus Proxy
    location / {
        proxy_redirect off;
        proxy_http_version 1.1;
        proxy_pass http://127.0.0.1:9090;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        
        # Timeouts
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }

    # Prometheus API
    location /api/ {
        proxy_redirect off;
        proxy_http_version 1.1;
        proxy_pass http://127.0.0.1:9090;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    include /etc/nginx/snippets/ssl.conf;
    include /etc/nginx/snippets/ssl-params.conf;
}
PROMETHEUS_NGINX_EOF

    echo -e "${GRAY}  ${ARROW}${NC} Testing Nginx configuration"
    echo -e "${GRAY}  ${ARROW}${NC} Reloading Nginx service"
    # Test and reload Nginx
    if nginx -t > /dev/null 2>&1; then
        systemctl reload nginx > /dev/null 2>&1
    fi

    echo -e "${GRAY}  ${ARROW}${NC} Updating Docker Compose with domain settings"
    # Update Docker Compose with domain configuration
    if [[ -n "$GRAFANA_DOMAIN" ]]; then
        sed -i '/GF_USERS_ALLOW_SIGN_UP=false/a\      - GF_SERVER_DOMAIN='$GRAFANA_DOMAIN'\n      - GF_SERVER_ROOT_URL=https://'$GRAFANA_DOMAIN docker-compose.yml
    fi

    # Add Prometheus external URL
    if [[ -n "$PROMETHEUS_DOMAIN" ]]; then
        sed -i '/--web.listen-address=0.0.0.0:9090/a\      - '\''--web.external-url=https://'$PROMETHEUS_DOMAIN''\' docker-compose.yml
    fi

    echo -e "${GREEN}${CHECK}${NC} Domain configuration completed successfully!"
}

#===========================
# SERVICE STARTUP FUNCTIONS
#===========================

# Configure UFW and start services
configure_firewall_and_startup() {
    echo
    echo -e "${GREEN}Service Startup${NC}"
    echo -e "${GREEN}===============${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Configuring firewall and starting services..."
    echo -e "${GRAY}  ${ARROW}${NC} Adding UFW firewall rules"
    echo -e "${GRAY}  ${ARROW}${NC} Starting Docker containers"
    echo -e "${GRAY}  ${ARROW}${NC} Building monitoring services"

    # UFW rules
    ufw allow 3000/tcp comment "Grafana" > /dev/null 2>&1 || true
    ufw allow 9090/tcp comment "Prometheus" > /dev/null 2>&1 || true

    # Start monitoring services
    docker compose up -d --build > /dev/null 2>&1

    echo -e "${GREEN}${CHECK}${NC} Services startup completed successfully!"
}

# Verify installation
verify_installation() {
    echo
    echo -e "${GREEN}Installation Verification${NC}"
    echo -e "${GREEN}=========================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Verifying monitoring installation..."
    echo -e "${GRAY}  ${ARROW}${NC} Waiting for services to initialize"
    
    # Wait for services to start
    sleep 15

    echo -e "${GRAY}  ${ARROW}${NC} Checking Node Exporter service"
    echo -e "${GRAY}  ${ARROW}${NC} Verifying Docker containers"
    echo -e "${GRAY}  ${ARROW}${NC} Testing network connectivity"
    echo -e "${GRAY}  ${ARROW}${NC} Validating metrics endpoints"

    # Verify Node Exporter
    if systemctl is-active --quiet node_exporter; then
        echo -e "${GRAY}  ${ARROW}${NC} Node Exporter: ${GREEN}Running${NC}"
    else
        echo -e "${GRAY}  ${ARROW}${NC} Node Exporter: ${RED}Not running${NC}"
    fi

    # Verify Docker containers
    if docker ps | grep -q "grafana\|prometheus\|marzban-exporter"; then
        echo -e "${GRAY}  ${ARROW}${NC} Docker containers: ${GREEN}Running${NC}"
    else
        echo -e "${GRAY}  ${ARROW}${NC} Docker containers: ${RED}Not running${NC}"
    fi

    # Check ports
    if ss -tlnp | grep -q 3000; then
        echo -e "${GRAY}  ${ARROW}${NC} Grafana port 3000: ${GREEN}Listening${NC}"
    else
        echo -e "${GRAY}  ${ARROW}${NC} Grafana port 3000: ${YELLOW}Not listening${NC}"
    fi

    if ss -tlnp | grep -q 9090; then
        echo -e "${GRAY}  ${ARROW}${NC} Prometheus port 9090: ${GREEN}Listening${NC}"
    else
        echo -e "${GRAY}  ${ARROW}${NC} Prometheus port 9090: ${YELLOW}Not listening${NC}"
    fi

    if ss -tlnp | grep -q 8080; then
        echo -e "${GRAY}  ${ARROW}${NC} Marzban Exporter port 8080: ${GREEN}Listening${NC}"
    else
        echo -e "${GRAY}  ${ARROW}${NC} Marzban Exporter port 8080: ${YELLOW}Not listening${NC}"
    fi

    echo -e "${GRAY}  ${ARROW}${NC} Testing Prometheus targets health"
    # Test Prometheus targets
    sleep 5
    if curl -s http://localhost:9090/api/v1/targets 2>/dev/null | grep -q '"health":"up"'; then
        echo -e "${GRAY}  ${ARROW}${NC} Prometheus targets: ${GREEN}Healthy${NC}"
    else
        echo -e "${GRAY}  ${ARROW}${NC} Prometheus targets: ${YELLOW}Some may be down${NC}"
    fi

    echo -e "${GRAY}  ${ARROW}${NC} Testing Marzban exporter endpoint"
    # Test Marzban exporter endpoint
    if curl -s http://127.0.0.1:8080/metrics 2>/dev/null | grep -q "# HELP"; then
        echo -e "${GRAY}  ${ARROW}${NC} Marzban exporter: ${GREEN}Accessible${NC}"
    else
        echo -e "${GRAY}  ${ARROW}${NC} Marzban exporter: ${YELLOW}Not responding${NC}"
    fi

    echo -e "${GREEN}${CHECK}${NC} Installation verification completed!"
}

# Display completion info
display_installation_completion() {
    echo

    echo -e "${PURPLE}=========================${NC}"
    echo -e "${GREEN}${CHECK}${NC} Installation complete!"
    echo -e "${PURPLE}=========================${NC}"
    echo

    if [[ -n "$GRAFANA_DOMAIN" && -n "$PROMETHEUS_DOMAIN" ]]; then
        echo -e "${CYAN}Access URLs:${NC}"
        echo -e "${WHITE}• https://$GRAFANA_DOMAIN${NC}"
        echo -e "${WHITE}• https://$PROMETHEUS_DOMAIN${NC}"
        echo
    fi
    
    echo -e "${CYAN}Useful Commands:${NC}"
    echo -e "${WHITE}• Check targets: curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'${NC}"
    echo -e "${WHITE}• View logs: docker compose logs -f marzban-exporter${NC}"
    echo
    
    echo -e "${CYAN}Next Steps:${NC}"
    echo -e "${WHITE}• Set up monitoring on servers with nodes.${NC}"
    echo -e "${WHITE}• Return to panel server and choose \"Add Nodes\".${NC}"
}

#==============================
# MAIN INSTALLATION FUNCTION
#==============================

# Install monitoring
install_monitoring() {
    echo
    # Get panel domain
    input_panel_domain
    
    # Get admin credentials for Marzban API
    input_admin_credentials

    echo
    # Confirm configuration
    echo -ne "${YELLOW}Continue with installation? (y/N): ${NC}"
    read -r CONFIRM

    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo
        echo -e "${CYAN}Installation cancelled.${NC}"
        return 0
    fi

    echo
    echo -e "${PURPLE}==============================${NC}"
    echo -e "${NC}Panel Monitoring Installation${NC}"
    echo -e "${PURPLE}==============================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Checking installation requirements..."
    echo -e "${GRAY}  ${ARROW}${NC} Verifying existing monitoring installation"
    echo -e "${GRAY}  ${ARROW}${NC} Checking Marzban panel installation"

    # Check if monitoring is already installed
    local status=$(check_monitoring_status)
    local monitoring_installed=$(echo $status | cut -d',' -f1)
    local node_exporter_installed=$(echo $status | cut -d',' -f2)
    
    if [ "$monitoring_installed" = "true" ] && [ "$node_exporter_installed" = "true" ]; then
        echo -e "${RED}${CROSS}${NC} Panel monitoring is already installed!"
        echo -e "${RED}Please uninstall it first if you want to reinstall.${NC}"
        return 1
    fi

    # Check if Marzban is installed
    if [ ! -d "/opt/marzban" ] || [ ! -f "/opt/marzban/.env" ]; then
        echo -e "${RED}${CROSS}${NC} Marzban panel not found!"
        echo -e "${RED}Please install Marzban first.${NC}"
        return 1
    fi
    
    echo -e "${GREEN}${CHECK}${NC} System requirements validated!"

    set -e

    # Execute installation steps
    install_node_exporter
    setup_monitoring_structure  
    create_environment_config
    create_docker_compose
    setup_grafana_provisioning
    configure_domains
    configure_firewall_and_startup
    verify_installation
    display_installation_completion
}

#=======================
# NODE MANAGEMENT FUNCTIONS
#=======================

# Add nodes to monitoring
add_nodes() {
    echo
    echo -e "${PURPLE}===============${NC}"
    echo -e "${NC}Node Management${NC}"
    echo -e "${PURPLE}===============${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Checking monitoring system status..."
    echo -e "${GRAY}  ${ARROW}${NC} Verifying panel monitoring installation"
    echo -e "${GRAY}  ${ARROW}${NC} Loading current configuration"
    
    # Check if monitoring is installed
    local status=$(check_monitoring_status)
    local monitoring_installed=$(echo $status | cut -d',' -f1)
    
    if [ "$monitoring_installed" != "true" ]; then
        echo -e "${RED}${CROSS}${NC} Panel monitoring is not installed!"
        echo -e "${RED}Please install panel monitoring first.${NC}"
        return 1
    fi

    echo -e "${GREEN}${CHECK}${NC} Monitoring system ready for node addition!"
    echo

    echo -e "${GREEN}Current Configuration${NC}"
    echo -e "${GREEN}=====================${NC}"
    echo

    echo -e "${CYAN}Current Prometheus configuration:${NC}"
    echo
    cat /opt/marzban-monitoring/prometheus/prometheus.yml
    echo

    echo -ne "${YELLOW}Do you want to add nodes to this configuration? (y/N): ${NC}"
    read -r PROCEED

    if [[ "$PROCEED" =~ ^[Nn]$ ]]; then
        echo -e "${CYAN}Operation cancelled.${NC}"
        return 0
    fi

    echo -e "${GREEN}Node Collection${NC}"
    echo -e "${GREEN}===============${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Collecting node information..."
    echo -e "${GRAY}  ${ARROW}${NC} Starting interactive node input"
    echo -e "${GRAY}  ${ARROW}${NC} Testing connectivity to each node"
    echo -e "${GRAY}  ${ARROW}${NC} Validating node accessibility"

    # Collect new nodes
    EXTERNAL_NODES=()
    while true; do
        echo
        echo -ne "${CYAN}Node IP (or press Enter to finish): ${NC}"
        read NODE_IP
        if [[ -z "$NODE_IP" ]]; then
            break
        fi
        
        # Basic IP validation
        if [[ $NODE_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            # Test connectivity
            if curl -s --max-time 5 http://$NODE_IP:9100/metrics > /dev/null 2>&1; then
                EXTERNAL_NODES+=("$NODE_IP:9100")
                echo -e "${GREEN}${CHECK}${NC} Node $NODE_IP:9100 is reachable"
            else
                echo -e "${YELLOW}${WARNING}${NC} Cannot reach $NODE_IP:9100"
                echo -ne "${YELLOW}Add anyway? (y/N): ${NC}"
                read -r ADD_ANYWAY
                if [[ "$ADD_ANYWAY" =~ ^[Yy]$ ]]; then
                    EXTERNAL_NODES+=("$NODE_IP:9100")
                fi
            fi
        else
            echo -e "${RED}${CROSS}${NC} Invalid IP format: $NODE_IP"
        fi
    done

    if [ ${#EXTERNAL_NODES[@]} -eq 0 ]; then
        echo -e "${YELLOW}No nodes were added.${NC}"
        return 0
    fi

    echo -e "${GREEN}${CHECK}${NC} Node collection completed!"
    echo

    echo -e "${GREEN}Configuration Update${NC}"
    echo -e "${GREEN}====================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Updating Prometheus configuration..."
    echo -e "${GRAY}  ${ARROW}${NC} Adding nodes to configuration file"
    echo -e "${GRAY}  ${ARROW}${NC} Updating scrape targets"
    echo -e "${GRAY}  ${ARROW}${NC} Reloading Prometheus service"
    
    # Add nodes to Prometheus config
    cd /opt/marzban-monitoring
    
    # Check if external nodes section already exists
    if grep -q "job_name: 'node-exporter-nodes'" prometheus/prometheus.yml; then
        # Add to existing section
        for node in "${EXTERNAL_NODES[@]}"; do
            if ! grep -q "$node" prometheus/prometheus.yml; then
                sed -i "/job_name: 'node-exporter-nodes'/,/^  - job_name:/{/- targets:/a\\        - '$node'" prometheus/prometheus.yml
            fi
        done
    else
        # Create new section
        cat >> prometheus/prometheus.yml << NODES_EOF

  - job_name: 'node-exporter-nodes'
    static_configs:
      - targets:
NODES_EOF
        for node in "${EXTERNAL_NODES[@]}"; do
            echo "        - '$node'" >> prometheus/prometheus.yml
        done
        cat >> prometheus/prometheus.yml << NODES_EOF2
    scrape_interval: 15s
    scrape_timeout: 5s
NODES_EOF2
    fi

    # Reload Prometheus
    if curl -s -X POST http://localhost:9090/-/reload > /dev/null 2>&1; then
        echo -e "${GRAY}  ${ARROW}${NC} Prometheus configuration reloaded successfully"
    else
        echo -e "${GRAY}  ${ARROW}${NC} Manual restart may be required"
    fi

    echo -e "${GREEN}${CHECK}${NC} Configuration update completed!"
    echo

    echo -e "${PURPLE}=================${NC}"
    echo -e "${GREEN}${CHECK}${NC} Nodes added!"
    echo -e "${PURPLE}=================${NC}"
    echo

    echo -e "${CYAN}Successfully added nodes:${NC}"
    for node in "${EXTERNAL_NODES[@]}"; do
        echo -e "${WHITE}• $node${NC}"
    done
}

#===============================
# UNINSTALLATION FUNCTIONS
#===============================

# Uninstall monitoring
uninstall_monitoring() {
    echo
    # Confirmation
    echo -ne "${YELLOW}Are you sure you want to continue? (y/N): ${NC}"
    read -r CONFIRM

    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo
        echo -e "${CYAN}Uninstallation cancelled.${NC}"
        return 0
    fi

    echo
    echo -e "${PURPLE}=============================${NC}"
    echo -e "${NC}Panel Monitoring Uninstaller${NC}"
    echo -e "${PURPLE}=============================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Checking current installation status..."
    echo -e "${GRAY}  ${ARROW}${NC} Scanning for monitoring components"
    echo -e "${GRAY}  ${ARROW}${NC} Identifying services to remove"

    # Check if monitoring is installed
    local status=$(check_monitoring_status)
    local monitoring_installed=$(echo $status | cut -d',' -f1)
    local node_exporter_installed=$(echo $status | cut -d',' -f2)
    
    if [ "$monitoring_installed" != "true" ] && [ "$node_exporter_installed" != "true" ]; then
        echo -e "${YELLOW}Panel monitoring is not installed on this system.${NC}"
        return 0
    fi

    echo -e "${GREEN}${CHECK}${NC} Installation status check completed!"
    echo

    echo -e "${GREEN}Docker Services Removal${NC}"
    echo -e "${GREEN}=======================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Removing Docker monitoring services..."
    echo -e "${GRAY}  ${ARROW}${NC} Stopping running containers"
    echo -e "${GRAY}  ${ARROW}${NC} Removing container images"
    echo -e "${GRAY}  ${ARROW}${NC} Cleaning up Docker volumes"

    # Stop and remove Docker containers
    cd /opt/marzban-monitoring 2>/dev/null
    if [ -f "docker-compose.yml" ]; then
        docker compose down > /dev/null 2>&1
    fi

    # Remove Docker volumes
    docker volume rm marzban-monitoring_grafana-storage > /dev/null 2>&1 || true
    docker volume rm marzban-monitoring_prom_data > /dev/null 2>&1 || true

    echo -e "${GREEN}${CHECK}${NC} Docker services removal completed!"
    echo

    echo -e "${GREEN}File System Cleanup${NC}"
    echo -e "${GREEN}===================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Removing monitoring files and directories..."
    echo -e "${GRAY}  ${ARROW}${NC} Removing monitoring directory"
    echo -e "${GRAY}  ${ARROW}${NC} Cleaning up configuration files"

    # Remove monitoring directory
    if [ -d "/opt/marzban-monitoring" ]; then
        rm -rf /opt/marzban-monitoring
    fi

    echo -e "${GREEN}${CHECK}${NC} File system cleanup completed!"
    echo

    echo -e "${GREEN}Node Exporter Removal${NC}"
    echo -e "${GREEN}=====================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Removing Node Exporter service..."
    echo -e "${GRAY}  ${ARROW}${NC} Stopping Node Exporter service"
    echo -e "${GRAY}  ${ARROW}${NC} Disabling system service"
    echo -e "${GRAY}  ${ARROW}${NC} Removing service files"
    echo -e "${GRAY}  ${ARROW}${NC} Cleaning up user accounts"

    # Stop and remove Node Exporter
    systemctl stop node_exporter > /dev/null 2>&1 || true
    systemctl disable node_exporter > /dev/null 2>&1 || true

    if [ -f "/etc/systemd/system/node_exporter.service" ]; then
        rm -f /etc/systemd/system/node_exporter.service
        systemctl daemon-reload > /dev/null 2>&1
    fi

    if [ -f "/usr/local/bin/node_exporter" ]; then
        rm -f /usr/local/bin/node_exporter
    fi

    # Remove user
    if id "node_exporter" &>/dev/null; then
        userdel node_exporter > /dev/null 2>&1 || true
    fi

    echo -e "${GREEN}${CHECK}${NC} Node Exporter removal completed!"
    echo

    echo -e "${GREEN}Web Server Configuration${NC}"
    echo -e "${GREEN}========================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Removing web server configurations..."
    echo -e "${GRAY}  ${ARROW}${NC} Removing Nginx configurations"
    echo -e "${GRAY}  ${ARROW}${NC} Removing firewall rules"
    echo -e "${GRAY}  ${ARROW}${NC} Reloading web server"

    # Remove Nginx configurations
    rm -f /etc/nginx/conf.d/grafana-monitoring.conf > /dev/null 2>&1 || true
    rm -f /etc/nginx/conf.d/prometheus-monitoring.conf > /dev/null 2>&1 || true
    
    # Reload Nginx if configs were removed
    if nginx -t > /dev/null 2>&1; then
        systemctl reload nginx > /dev/null 2>&1 || true
    fi

    # Remove UFW rules
    ufw delete allow 3000/tcp > /dev/null 2>&1 || true
    ufw delete allow 9090/tcp > /dev/null 2>&1 || true

    echo -e "${GREEN}${CHECK}${NC} Web server configuration cleanup completed!"
    echo

    echo -e "${PURPLE}===========================${NC}"
    echo -e "${GREEN}${CHECK}${NC} Uninstallation complete!"
    echo -e "${PURPLE}===========================${NC}"
    echo
    echo -e "${CYAN}All monitoring components have been successfully removed.${NC}"
}

#====================
# MENU FUNCTIONS
#====================

# Show main menu
show_main_menu() {
    local status=$(check_monitoring_status)
    local monitoring_installed=$(echo $status | cut -d',' -f1)
    
    echo -e "${CYAN}Please select an action:${NC}"
    echo
    if [ "$monitoring_installed" = "true" ]; then
        echo -e "${BLUE}1.${NC} Show Status"
        echo -e "${GREEN}2.${NC} Add Nodes"
        echo -e "${YELLOW}3.${NC} Uninstall"
        echo -e "${RED}4.${NC} Exit"
    else
        echo -e "${GREEN}1.${NC} Install"
        echo -e "${YELLOW}2.${NC} Uninstall"
        echo -e "${RED}3.${NC} Exit"
    fi
    echo
}

# Handle user choice
handle_user_choice() {
    local status=$(check_monitoring_status)
    local monitoring_installed=$(echo $status | cut -d',' -f1)
    
    while true; do
        if [ "$monitoring_installed" = "true" ]; then
            echo -ne "${CYAN}Enter your choice (1-4): ${NC}"
            read CHOICE
        else
            echo -ne "${CYAN}Enter your choice (1-3): ${NC}"
            read CHOICE
        fi
        
        case $CHOICE in
            1)
                if [ "$monitoring_installed" = "true" ]; then
                    show_status
                else
                    install_monitoring
                fi
                break
                ;;
            2)
                if [ "$monitoring_installed" = "true" ]; then
                    add_nodes
                else
                    uninstall_monitoring
                fi
                break
                ;;
            3)
                if [ "$monitoring_installed" = "true" ]; then
                    uninstall_monitoring
                else
                    echo -e "${CYAN}Goodbye!${NC}"
                    exit 0
                fi
                break
                ;;
            4)
                if [ "$monitoring_installed" = "true" ]; then
                    echo -e "${CYAN}Goodbye!${NC}"
                    exit 0
                else
                    echo -e "${RED}${CROSS}${NC} Invalid choice. Please enter 1, 2, or 3."
                fi
                ;;
            *)
                if [ "$monitoring_installed" = "true" ]; then
                    echo -e "${RED}${CROSS}${NC} Invalid choice. Please enter 1, 2, 3, or 4."
                else
                    echo -e "${RED}${CROSS}${NC} Invalid choice. Please enter 1, 2, or 3."
                fi
                ;;
        esac
    done
}

#==================
# MAIN ENTRY POINT
#==================

# Main function
main() {
    # Check root privileges first
    check_root_privileges

    # Display script header
    echo
    echo -e "${PURPLE}=========================${NC}"
    echo -e "${NC}MARZBAN PANEL MONITORING${NC}"
    echo -e "${PURPLE}=========================${NC}"
    echo

    # Show menu and handle user choice
    show_main_menu
    handle_user_choice
    echo
}

# Execute main function
main
