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

# Check if running as root
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}This script must be run as root${NC}"
    exit 1
fi

# Marzban Panel Monitoring Management Script
echo
echo -e "${PURPLE}=========================${NC}"
echo -e "${NC}MARZBAN PANEL MONITORING${NC}"
echo -e "${PURPLE}=========================${NC}"
echo

# Function to check monitoring status
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

# Function to show current status
show_status() {
    echo
    echo -e "${PURPLE}=========================${NC}"
    echo -e "${NC}Current Monitoring Status${NC}"
    echo -e "${PURPLE}=========================${NC}"
    echo
    
    local status=$(check_monitoring_status)
    local monitoring_installed=$(echo $status | cut -d',' -f1)
    local node_exporter_installed=$(echo $status | cut -d',' -f2)
    
    # Check monitoring installation
    if [ "$monitoring_installed" = "true" ]; then
        echo -e "${GREEN}✓${NC} Panel monitoring is installed"
    else
        echo -e "${RED}✗${NC} Panel monitoring is not installed"
        return
    fi
    
    # Check Node Exporter
    if [ "$node_exporter_installed" = "true" ]; then
        echo -e "${GREEN}✓${NC} Node Exporter is running"
    else
        echo -e "${RED}✗${NC} Node Exporter is not running"
    fi
    
    # Check Docker containers
    if docker ps | grep -q "grafana\|prometheus\|marzban-exporter"; then
        echo -e "${GREEN}✓${NC} Monitoring containers are running"
    else
        echo -e "${RED}✗${NC} Monitoring containers are not running"
    fi
    
    # Check Marzban container
    if docker ps | grep -q "marzban"; then
        echo -e "${GREEN}✓${NC} Marzban container is running"
    else
        echo -e "${RED}✗${NC} Marzban container is not running"
    fi
    
    # Check ports
    if ss -tlnp | grep -q 3000; then
        echo -e "${GREEN}✓${NC} Port 3000 (Grafana) is listening"
    else
        echo -e "${YELLOW}⚠${NC} Port 3000 (Grafana) is not listening"
    fi

    if ss -tlnp | grep -q 9090; then
        echo -e "${GREEN}✓${NC} Port 9090 (Prometheus) is listening"
    else
        echo -e "${YELLOW}⚠${NC} Port 9090 (Prometheus) is not listening"
    fi

    if ss -tlnp | grep -q 8080; then
        echo -e "${GREEN}✓${NC} Port 8080 (Marzban Exporter) is listening"
    else
        echo -e "${YELLOW}⚠${NC} Port 8080 (Marzban Exporter) is not listening"
    fi
    
    # Show current targets
    if [ -f "/opt/marzban-monitoring/prometheus/prometheus.yml" ]; then
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
            echo
        fi
    fi
}

# Function to install monitoring
install_monitoring() {
    echo
    echo -e "${PURPLE}==============================${NC}"
    echo -e "${NC}Panel Monitoring Installation${NC}"
    echo -e "${PURPLE}==============================${NC}"
    echo

    # Check if monitoring is already installed
    local status=$(check_monitoring_status)
    local monitoring_installed=$(echo $status | cut -d',' -f1)
    local node_exporter_installed=$(echo $status | cut -d',' -f2)
    
    if [ "$monitoring_installed" = "true" ] && [ "$node_exporter_installed" = "true" ]; then
        echo -e "${RED}Error: Panel monitoring is already installed!${NC}"
        echo -e "${RED}Please uninstall it first if you want to reinstall.${NC}"
        return 1
    fi

    # Check if Marzban is installed
    if [ ! -d "/opt/marzban" ] || [ ! -f "/opt/marzban/.env" ]; then
        echo -e "${RED}Error: Marzban panel not found!${NC}"
        echo -e "${RED}Please install Marzban first.${NC}"
        return 1
    fi
    
    # Get panel domain
    echo -ne "${CYAN}Panel domain (e.g., dash.example.com): ${NC}"
    read PANEL_DOMAIN
    while [[ -z "$PANEL_DOMAIN" ]]; do
        echo -e "${RED}Panel domain cannot be empty!${NC}"
        echo -ne "${CYAN}Panel domain: ${NC}"
        read PANEL_DOMAIN
    done

    # Get admin credentials for Marzban API
    echo -ne "${CYAN}Panel admin username: ${NC}"
    read MARZBAN_USERNAME
    MARZBAN_USERNAME=${MARZBAN_USERNAME:-admin}
    
    echo -ne "${CYAN}Panel admin password: ${NC}"
    read MARZBAN_PASSWORD
    echo
    while [[ -z "$MARZBAN_PASSWORD" ]]; do
        echo -e "${RED}Password cannot be empty!${NC}"
        echo -ne "${CYAN}Admin password: ${NC}"
        read MARZBAN_PASSWORD
        echo
    done

    # Confirm configuration
    echo -ne "${YELLOW}Continue with installation? (y/N): ${NC}"
    read -r CONFIRM

    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}Installation cancelled.${NC}"
        return 0
    fi

    set -e

    echo
    echo -e "${GREEN}============================${NC}"
    echo -e "${NC}1. Installing Node Exporter${NC}"
    echo -e "${GREEN}============================${NC}"
    echo

    # Check if Node Exporter is already installed and running
    if [ -f "/usr/local/bin/node_exporter" ] && systemctl is-active --quiet node_exporter; then
        echo -e "${YELLOW}Node Exporter is already installed and running${NC}"
        echo -e "${GREEN}✓${NC} Skipping Node Exporter installation"
    else
        # Stop Node Exporter if it's running
        if systemctl is-active --quiet node_exporter; then
            echo "Stopping existing Node Exporter..."
            systemctl stop node_exporter
        fi

        # Download and install Node Exporter
        echo "Downloading Node Exporter..."
        wget -q https://github.com/prometheus/node_exporter/releases/download/v1.9.1/node_exporter-1.9.1.linux-amd64.tar.gz
        tar xvf node_exporter-1.9.1.linux-amd64.tar.gz > /dev/null
        cp node_exporter-1.9.1.linux-amd64/node_exporter /usr/local/bin/
        rm -rf node_exporter-1.9.1.linux-amd64*

        # Create user and service
        echo "Creating Node Exporter user and service..."
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

        # Start Node Exporter
        systemctl daemon-reload
        systemctl enable node_exporter
        systemctl start node_exporter
    fi

    echo
    echo -e "${GREEN}----------------------------------------${NC}"
    echo -e "${GREEN}✓${NC} Node Exporter installation completed!"
    echo -e "${GREEN}----------------------------------------${NC}"
    echo

    echo -e "${GREEN}=========================${NC}"
    echo -e "${NC}2. Setting up monitoring${NC}"
    echo -e "${GREEN}=========================${NC}"
    echo

    # Check and install git if needed
    if ! command -v git &> /dev/null; then
        echo "Installing git..."
        apt update > /dev/null 2>&1
        apt install -y git > /dev/null 2>&1
        echo -e "${GREEN}✓${NC} Git installed successfully"
    fi

    # Create monitoring structure
    echo "Creating monitoring structure..."
    mkdir -p /opt/marzban-monitoring
    cd /opt/marzban-monitoring

    # Clone marzban-exporter
    echo "Cloning kutovoys/marzban-exporter..."
    if [ -d "marzban-exporter" ]; then
        rm -rf marzban-exporter
    fi
    git clone https://github.com/kutovoys/marzban-exporter.git

    # Collect external nodes
    echo
    echo -ne "${YELLOW}Do you want to add external nodes to monitoring? (y/N): ${NC}"
    read -r ADD_EXTERNAL_NODES
    
    EXTERNAL_NODES=()
    if [[ ! "$ADD_EXTERNAL_NODES" =~ ^[Nn]$ ]]; then
        while true; do
            echo
            echo -ne "${CYAN}Node IP (or press Enter to finish): ${NC}"
            read NODE_IP
            echo
            if [[ -z "$NODE_IP" ]]; then
                break
            fi
            
            # Basic IP validation
            if [[ $NODE_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                # Test connectivity
                echo "Testing connectivity to $NODE_IP:9100..."
                if curl -s --max-time 5 http://$NODE_IP:9100/metrics > /dev/null 2>&1; then
                    EXTERNAL_NODES+=("$NODE_IP:9100")
                else
                    echo -e "${YELLOW}Warning: Cannot reach $NODE_IP:9100${NC}"
                    echo
                    echo -ne "${YELLOW}Add anyway? (y/N): ${NC}"
                    read -r ADD_ANYWAY
                    if [[ "$ADD_ANYWAY" =~ ^[Yy]$ ]]; then
                        EXTERNAL_NODES+=("$NODE_IP:9100")
                    fi
                fi
            else
                echo -e "${RED}Invalid IP format: $NODE_IP${NC}"
                echo
            fi
        done

        if [ ${#EXTERNAL_NODES[@]} -gt 0 ]; then
            echo -e "${CYAN}External nodes to be added:${NC}"
            for node in "${EXTERNAL_NODES[@]}"; do
                echo -e "${WHITE}$node${NC}"
            done
        fi
    fi

    # Create Prometheus configuration
    echo
    echo "Creating Prometheus configuration..."
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

    # Add external nodes section if any were provided
    if [ ${#EXTERNAL_NODES[@]} -gt 0 ]; then
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

    # Create environment file for marzban-exporter
    echo "Creating environment configuration..."
    cat > marzban-exporter/.env << ENV_EOF
MARZBAN_BASE_URL=https://${PANEL_DOMAIN}
MARZBAN_USERNAME=${MARZBAN_USERNAME}
MARZBAN_PASSWORD=${MARZBAN_PASSWORD}
ENV_EOF

    # Also create command line args file
    echo "Creating marzban-exporter configuration..."
    cat > marzban-exporter/config.env << CONFIG_EOF
MARZBAN_BASE_URL=https://${PANEL_DOMAIN}
MARZBAN_USERNAME=${MARZBAN_USERNAME}  
MARZBAN_PASSWORD=${MARZBAN_PASSWORD}
CONFIG_EOF
    
    # Create Docker Compose for monitoring
    echo "Creating Docker Compose configuration..."
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
    ports:
      - "127.0.0.1:3000:3000"
    volumes:
      - grafana-storage:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
      - ./grafana/dashboards:/var/lib/grafana/dashboards
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    networks:
      - monitoring
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

    # Create Grafana provisioning
    echo "Setting up Grafana provisioning..."
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

    echo
    echo -e "${GREEN}------------------------------${NC}"
    echo -e "${GREEN}✓${NC} Monitoring setup completed!"
    echo -e "${GREEN}------------------------------${NC}"

    echo
    echo -e "${GREEN}=======================${NC}"
    echo -e "${NC}3. Configuring domains${NC}"
    echo -e "${GREEN}=======================${NC}"
    echo

    # Auto-generate domains from base domain
    BASE_DOMAIN=$(echo "$PANEL_DOMAIN" | awk -F'.' '{if (NF > 2) {print $(NF-1)"."$NF} else {print $0}}')
    GRAFANA_DOMAIN="grafana.$BASE_DOMAIN"
    PROMETHEUS_DOMAIN="prometheus.$BASE_DOMAIN"

        # Create Grafana Nginx config
        echo "Creating Grafana Nginx configuration..."
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
        echo "Creating Prometheus Nginx configuration..."
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

        # Test and reload Nginx
        echo "Testing and reloading Nginx..."
        if nginx -t; then
            systemctl reload nginx
            echo -e "${GREEN}✓${NC} Nginx configurations created and reloaded"
        else
            echo -e "${YELLOW}⚠${NC} Nginx configuration has errors, skipping reload"
        fi

    # Update Docker Compose with domain configuration
    echo "Updating Docker Compose with domain configuration..."
    
    # Add Grafana domain settings
    if [[ -n "$GRAFANA_DOMAIN" ]]; then
        sed -i '/GF_USERS_ALLOW_SIGN_UP=false/a\      - GF_SERVER_DOMAIN='$GRAFANA_DOMAIN'\n      - GF_SERVER_ROOT_URL=https://'$GRAFANA_DOMAIN docker-compose.yml
    fi

    # Add Prometheus external URL
    if [[ -n "$PROMETHEUS_DOMAIN" ]]; then
        sed -i '/--web.listen-address=0.0.0.0:9090/a\      - '\''--web.external-url=https://'$PROMETHEUS_DOMAIN''\' docker-compose.yml
    fi

    echo
    echo -e "${GREEN}----------------------------------${NC}"
    echo -e "${GREEN}✓${NC} Domain configuration completed!"
    echo -e "${GREEN}----------------------------------${NC}"
    echo

    echo -e "${GREEN}===================${NC}"
    echo -e "${NC}4. UFW and startup${NC}"
    echo -e "${GREEN}===================${NC}"
    echo

    # UFW rules
    echo "Adding UFW rules..."
    ufw allow 3000/tcp comment "Grafana" > /dev/null 2>&1 || true
    ufw allow 9090/tcp comment "Prometheus" > /dev/null 2>&1 || true

    # Start monitoring services
    echo "Starting monitoring services..."
    docker compose up -d --build

    echo
    echo -e "${GREEN}------------------------------${NC}"
    echo -e "${GREEN}✓${NC} Services startup completed!"
    echo -e "${GREEN}------------------------------${NC}"
    echo

    echo -e "${GREEN}======================${NC}"
    echo -e "${NC}5. Final verification${NC}"
    echo -e "${GREEN}======================${NC}"
    echo

    # Wait for services to start
    echo "Waiting for services to start..."
    sleep 15

    # Verify Node Exporter
    if systemctl is-active --quiet node_exporter; then
        echo -e "${GREEN}✓${NC} Node Exporter is running"
    else
        echo -e "${RED}✗${NC} Node Exporter is not running"
    fi

    # Verify Docker containers
    if docker ps | grep -q "grafana\|prometheus\|marzban-exporter"; then
        echo -e "${GREEN}✓${NC} Monitoring containers are running"
    else
        echo -e "${RED}✗${NC} Monitoring containers are not running"
    fi

    # Check ports
    if ss -tlnp | grep -q 3000; then
        echo -e "${GREEN}✓${NC} Port 3000 (Grafana) is listening"
    else
        echo -e "${YELLOW}⚠${NC} Port 3000 (Grafana) is not listening"
    fi

    if ss -tlnp | grep -q 9090; then
        echo -e "${GREEN}✓${NC} Port 9090 (Prometheus) is listening"
    else
        echo -e "${YELLOW}⚠${NC} Port 9090 (Prometheus) is not listening"
    fi

    if ss -tlnp | grep -q 8080; then
        echo -e "${GREEN}✓${NC} Port 8080 (Marzban Exporter) is listening"
    else
        echo -e "${YELLOW}⚠${NC} Port 8080 (Marzban Exporter) is not listening"
    fi

    # Test Prometheus targets
    echo "Checking Prometheus targets..."
    sleep 5
    if curl -s http://localhost:9090/api/v1/targets 2>/dev/null | grep -q '"health":"up"'; then
        echo -e "${GREEN}✓${NC} Prometheus targets are healthy"
    else
        echo -e "${YELLOW}⚠${NC} Some Prometheus targets may be down"
    fi

    # Test Marzban exporter endpoint
    echo "Checking Marzban exporter..."
    if curl -s http://127.0.0.1:8080/metrics 2>/dev/null | grep -q "# HELP"; then
        echo -e "${GREEN}✓${NC} Marzban exporter is accessible"
    else
        echo -e "${YELLOW}⚠${NC} Marzban exporter endpoint is not responding"
        echo -e "${CYAN}Check logs: docker compose logs marzban-exporter${NC}"
    fi

    echo
    echo -e "${GREEN}--------------------------------${NC}"
    echo -e "${GREEN}✓${NC} Final verification completed!"
    echo -e "${GREEN}--------------------------------${NC}"
    echo

    echo -e "${GREEN}==========================================================${NC}"
    echo -e "${GREEN}✓${NC} Marzban monitoring installation completed successfully!"
    echo -e "${GREEN}==========================================================${NC}"
    echo
    if [[ -n "$GRAFANA_DOMAIN" && -n "$PROMETHEUS_DOMAIN" ]]; then
        echo -e "${CYAN}Domain URLs:${NC}"
        echo -e "${WHITE}https://$GRAFANA_DOMAIN${NC}"
        echo -e "${WHITE}https://$PROMETHEUS_DOMAIN${NC}"
        echo
    fi
    echo -e "${CYAN}Check all targets:${NC}"
    echo -e "${WHITE}curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'${NC}"
    echo
    echo -e "${CYAN}Check logs:${NC}"
    echo -e "${WHITE}docker compose logs -f marzban-exporter${NC}"
    echo
}

# Function to add nodes
add_nodes() {
    echo
    echo -e "${PURPLE}===================${NC}"
    echo -e "${NC}Add Nodes to Panel${NC}"
    echo -e "${PURPLE}===================${NC}"
    echo

    # Check if monitoring is installed
    local status=$(check_monitoring_status)
    local monitoring_installed=$(echo $status | cut -d',' -f1)
    
    if [ "$monitoring_installed" != "true" ]; then
        echo -e "${RED}Error: Panel monitoring is not installed!${NC}"
        echo -e "${RED}Please install panel monitoring first.${NC}"
        return 1
    fi

    echo -e "${CYAN}Current Prometheus configuration:${NC}"
    echo
    cat /opt/marzban-monitoring/prometheus/prometheus.yml
    echo

    echo -ne "${YELLOW}Do you want to add nodes to this configuration? (y/N): ${NC}"
    read -r PROCEED

    if [[ "$PROCEED" =~ ^[Nn]$ ]]; then
        echo
        echo -e "${CYAN}Operation cancelled.${NC}"
        echo
        return 0
    fi

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
            echo "Testing connectivity to $NODE_IP:9100..."
            if curl -s --max-time 5 http://$NODE_IP:9100/metrics > /dev/null 2>&1; then
                EXTERNAL_NODES+=("$NODE_IP:9100")
                echo -e "${GREEN}✓${NC} Node $NODE_IP:9100 is reachable"
            else
                echo -e "${YELLOW}Warning: Cannot reach $NODE_IP:9100${NC}"
                echo -ne "${YELLOW}Add anyway? (y/N): ${NC}"
                read -r ADD_ANYWAY
                if [[ "$ADD_ANYWAY" =~ ^[Yy]$ ]]; then
                    EXTERNAL_NODES+=("$NODE_IP:9100")
                fi
            fi
        else
            echo -e "${RED}Invalid IP format: $NODE_IP${NC}"
        fi
    done

    if [ ${#EXTERNAL_NODES[@]} -eq 0 ]; then
        echo -e "${YELLOW}No nodes were added.${NC}"
        return 0
    fi

    # Add nodes to Prometheus config
    echo
    echo "Adding nodes to Prometheus configuration..."
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
    echo "Reloading Prometheus configuration..."
    if curl -s -X POST http://localhost:9090/-/reload > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Prometheus configuration reloaded"
    else
        echo -e "${YELLOW}⚠${NC} Could not reload Prometheus automatically"
        echo -e "${CYAN}Restart containers: docker compose restart prometheus${NC}"
    fi

    echo
    echo -e "${GREEN}Nodes added successfully:${NC}"
    for node in "${EXTERNAL_NODES[@]}"; do
        echo -e "${WHITE}- $node${NC}"
    done
    echo
}

# Function to uninstall monitoring (same as before)
uninstall_monitoring() {
    echo
    echo -e "${PURPLE}=============================${NC}"
    echo -e "${NC}Panel Monitoring Uninstaller${NC}"
    echo -e "${PURPLE}=============================${NC}"
    echo

    # Check if monitoring is installed
    local status=$(check_monitoring_status)
    local monitoring_installed=$(echo $status | cut -d',' -f1)
    local node_exporter_installed=$(echo $status | cut -d',' -f2)
    
    if [ "$monitoring_installed" != "true" ] && [ "$node_exporter_installed" != "true" ]; then
        echo -e "${YELLOW}Panel monitoring is not installed on this system.${NC}"
        echo
        return 0
    fi

    # Confirmation
    echo -ne "${YELLOW}Are you sure you want to continue? (y/N): ${NC}"
    read -r CONFIRM

    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo
        echo -e "${CYAN}Uninstallation cancelled.${NC}"
        echo
        return 0
    fi

    echo
    echo -e "${GREEN}=============================${NC}"
    echo -e "${NC}Removing monitoring services${NC}"
    echo -e "${GREEN}=============================${NC}"
    echo

    # Stop and remove Docker containers
    echo "Stopping and removing monitoring containers..."
    cd /opt/marzban-monitoring 2>/dev/null
    if [ -f "docker-compose.yml" ]; then
        docker compose down 2>/dev/null && echo -e "${GREEN}✓${NC} Monitoring containers stopped" || echo "ℹ Containers were not running"
    fi

    # Remove Docker volumes
    echo
    echo "Removing Docker volumes..."
    docker volume rm marzban-monitoring_grafana-storage 2>/dev/null && echo -e "${GREEN}✓${NC} Grafana volume removed" || echo "ℹ Grafana volume not found"
    docker volume rm marzban-monitoring_prom_data 2>/dev/null && echo -e "${GREEN}✓${NC} Prometheus volume removed" || echo "ℹ Prometheus volume not found"

    # Remove monitoring directory
    echo
    echo "Removing monitoring directory..."
    if [ -d "/opt/marzban-monitoring" ]; then
        rm -rf /opt/marzban-monitoring
        echo -e "${GREEN}✓${NC} Monitoring directory removed"
    else
        echo "ℹ Monitoring directory not found"
    fi

    # Stop and remove Node Exporter
    echo
    echo "Removing Node Exporter..."
    systemctl stop node_exporter 2>/dev/null && echo -e "${GREEN}✓${NC} Node Exporter stopped" || echo "ℹ Node Exporter was not running"
    systemctl disable node_exporter 2>/dev/null && echo -e "${GREEN}✓${NC} Node Exporter disabled" || echo "ℹ Node Exporter was not enabled"

    if [ -f "/etc/systemd/system/node_exporter.service" ]; then
        rm -f /etc/systemd/system/node_exporter.service
        systemctl daemon-reload
        echo -e "${GREEN}✓${NC} Node Exporter service removed"
    else
        echo "ℹ Node Exporter service file not found"
    fi

    if [ -f "/usr/local/bin/node_exporter" ]; then
        rm -f /usr/local/bin/node_exporter
        echo -e "${GREEN}✓${NC} Node Exporter binary removed"
    else
        echo "ℹ Node Exporter binary not found"
    fi

    # Remove user
    if id "node_exporter" &>/dev/null; then
        userdel node_exporter 2>/dev/null
        echo -e "${GREEN}✓${NC} Node Exporter user removed"
    else
        echo "ℹ Node Exporter user not found"
    fi

    # Remove Nginx configurations
    echo
    echo "Removing Nginx configurations..."
    rm -f /etc/nginx/conf.d/grafana-monitoring.conf 2>/dev/null && echo -e "${GREEN}✓${NC} Grafana Nginx config removed" || echo "ℹ Grafana Nginx config not found"
    rm -f /etc/nginx/conf.d/prometheus-monitoring.conf 2>/dev/null && echo -e "${GREEN}✓${NC} Prometheus Nginx config removed" || echo "ℹ Prometheus Nginx config not found"
    
    # Reload Nginx if configs were removed
    if nginx -t 2>/dev/null; then
        systemctl reload nginx 2>/dev/null && echo -e "${GREEN}✓${NC} Nginx reloaded" || echo "ℹ Nginx reload skipped"
    fi

    # Remove UFW rules
    echo
    echo "Removing UFW rules..."
    ufw delete allow 3000/tcp 2>/dev/null && echo -e "${GREEN}✓${NC} Grafana UFW rule removed" || echo "ℹ Grafana UFW rule not found"
    ufw delete allow 9090/tcp 2>/dev/null && echo -e "${GREEN}✓${NC} Prometheus UFW rule removed" || echo "ℹ Prometheus UFW rule not found"

    echo
    echo -e "${GREEN}===============================================${NC}"
    echo -e "${GREEN}✓${NC} Marzban monitoring uninstalled successfully!"
    echo -e "${GREEN}===============================================${NC}"
    echo
}

# Main menu function
main_menu() {
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
                    echo -e "${RED}Invalid choice. Please enter 1, 2, or 3.${NC}"
                fi
                ;;
            *)
                if [ "$monitoring_installed" = "true" ]; then
                    echo -e "${RED}Invalid choice. Please enter 1, 2, 3, or 4.${NC}"
                else
                    echo -e "${RED}Invalid choice. Please enter 1, 2, or 3.${NC}"
                fi
                ;;
        esac
    done
}

# Always show interactive menu
main_menu
