#!/bin/bash

#================================
# UPTIME KUMA MONITORING MANAGER
#================================

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
KUMA_DOMAIN=""
VLESS_LINKS=()

#======================
# VALIDATION FUNCTIONS
#======================

# Check root privileges
check_root_privileges() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}${CROSS}${NC} This script must be run as root"
        echo
        exit 1
    fi
}

# Check installation status
check_installation_status() {
    local kuma_installed=false
    
    if [ -d "/root/kuma" ] && [ -f "/root/kuma/docker-compose.yml" ] && docker ps | grep -q "uptime-kuma"; then
        kuma_installed=true
    fi
    
    echo "$kuma_installed"
}

#==================
# STATUS FUNCTIONS
#==================

# Show current status
show_status() {
    echo
    echo -e "${PURPLE}===================${NC}"
    echo -e "${NC}Uptime Kuma Status${NC}"
    echo -e "${PURPLE}===================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Checking Uptime Kuma installation status..."
    echo -e "${GRAY}  ${ARROW}${NC} Verifying installation directory"
    echo -e "${GRAY}  ${ARROW}${NC} Checking Docker containers"
    echo -e "${GRAY}  ${ARROW}${NC} Validating service ports"
    
    local kuma_installed=$(check_installation_status)
    
    if [ "$kuma_installed" != "true" ]; then
        echo -e "${RED}${CROSS}${NC} Uptime Kuma is not installed"
        echo
        return
    fi
    
    echo -e "${GREEN}${CHECK}${NC} Status check completed!"
    echo

    echo -e "${GREEN}Service Status${NC}"
    echo -e "${GREEN}==============${NC}"
    echo

    # Check installation
    if [ "$kuma_installed" = "true" ]; then
        echo -e "${GREEN}${CHECK}${NC} Uptime Kuma is installed"
    else
        echo -e "${RED}${CROSS}${NC} Uptime Kuma is not installed"
    fi
    
    # Check Docker containers
    if docker ps | grep -q "uptime-kuma"; then
        echo -e "${GREEN}${CHECK}${NC} Uptime Kuma container is running"
    else
        echo -e "${RED}${CROSS}${NC} Uptime Kuma container is not running"
    fi
    
    if docker ps | grep -q "xray-checker"; then
        echo -e "${GREEN}${CHECK}${NC} Xray Checker container is running"
    else
        echo -e "${RED}${CROSS}${NC} Xray Checker container is not running"
    fi
    
    # Check ports
    if ss -tlnp | grep -q 3001; then
        echo -e "${GREEN}${CHECK}${NC} Port 3001 (Uptime Kuma) is listening"
    else
        echo -e "${YELLOW}${WARNING}${NC} Port 3001 (Uptime Kuma) is not listening"
    fi

    # Check Nginx configuration
    if [ -f "/etc/nginx/conf.d/kuma.conf" ]; then
        echo -e "${GREEN}${CHECK}${NC} Nginx configuration exists"
        
        # Extract domain from nginx config
        local configured_domain=$(grep "server_name" /etc/nginx/conf.d/kuma.conf | awk '{print $2}' | sed 's/;//')
        if [ -n "$configured_domain" ]; then
            echo -e "${GREEN}${CHECK}${NC} Configured domain: ${WHITE}$configured_domain${NC}"
        fi
    else
        echo -e "${YELLOW}${WARNING}${NC} Nginx configuration not found"
    fi
    
    # Show configuration
    if [ -f "/root/kuma/config.json" ]; then
        echo

        echo -e "${GREEN}Configuration${NC}"
        echo -e "${GREEN}=============${NC}"
        echo
        
        # Show configured links count
        local links_count=$(grep -o '"link":' /root/kuma/config.json | wc -l)
        echo -e "${WHITE}• Configured VLESS links: $links_count${NC}"
        
        # Show proxy start port
        local proxy_port=$(grep '"proxyStartPort":' /root/kuma/config.json | grep -o '[0-9]*')
        if [ -n "$proxy_port" ]; then
            echo -e "${WHITE}• Proxy start port: $proxy_port${NC}"
        fi
    fi
}

#============================
# INPUT VALIDATION FUNCTIONS
#============================

# Input domain
input_domain() {
    while true; do
        echo -ne "${CYAN}Kuma domain (e.g., kuma.example.com): ${NC}"
        read KUMA_DOMAIN
        if [[ -n "$KUMA_DOMAIN" ]]; then
            break
        fi
        echo -e "${RED}${CROSS}${NC} Domain cannot be empty!"
    done
}

# Input VLESS links
input_vless_links() {
    echo
    echo -e "${GREEN}VLESS Links Collection${NC}"
    echo -e "${GREEN}======================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Collecting VLESS links..."
    echo -e "${YELLOW}  Enter your VLESS links one by one${NC}"
    echo

    VLESS_LINKS=()
    local link_count=1
    
    while true; do
        echo -ne "${CYAN}VLESS link #$link_count (or press Enter to finish): ${NC}"
        read vless_link
        if [[ -z "$vless_link" ]]; then
            break
        fi
        
        # Basic VLESS link validation
        if [[ $vless_link =~ ^vless:// ]]; then
            VLESS_LINKS+=("$vless_link")
            echo -e "${GREEN}${CHECK}${NC} Link #$link_count added successfully"
            echo
            ((link_count++))
        else
            echo -e "${RED}${CROSS}${NC} Invalid VLESS link format!"
            echo
        fi
    done

    if [ ${#VLESS_LINKS[@]} -eq 0 ]; then
        echo -e "${YELLOW}${WARNING}${NC} No VLESS links were added!"
        return 1
    fi

    echo -e "${GREEN}${CHECK}${NC} Collected ${#VLESS_LINKS[@]} VLESS link(s)"
}

#========================
# INSTALLATION FUNCTIONS
#========================

# Create Nginx configuration
create_nginx_config() {
    echo
    echo -e "${GREEN}Nginx Configuration${NC}"
    echo -e "${GREEN}===================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Creating Nginx configuration..."
    echo -e "${GRAY}  ${ARROW}${NC} Generating proxy configuration"
    echo -e "${GRAY}  ${ARROW}${NC} Setting up SSL configuration"
    echo -e "${GRAY}  ${ARROW}${NC} Configuring reverse proxy rules"

    cat > /etc/nginx/conf.d/kuma.conf << NGINX_EOF
server {
    server_name  $KUMA_DOMAIN;

    listen       443 ssl;

    location / {
        proxy_pass              http://127.0.0.1:3001;
        proxy_set_header        Host \$host;
        proxy_set_header        X-Real-IP \$remote_addr;
        proxy_set_header        X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto \$scheme;
    }

    include      /etc/nginx/snippets/ssl.conf;
    include      /etc/nginx/snippets/ssl-params.conf;
}
NGINX_EOF

    echo -e "${GRAY}  ${ARROW}${NC} Testing Nginx configuration"
    if nginx -t > /dev/null 2>&1; then
        echo -e "${GRAY}  ${ARROW}${NC} Reloading Nginx service"
        systemctl restart nginx > /dev/null 2>&1
        echo -e "${GREEN}${CHECK}${NC} Nginx configuration created successfully!"
    else
        echo -e "${RED}${CROSS}${NC} Nginx configuration test failed!"
        return 1
    fi
}

# Create Docker structure
create_docker_structure() {
    echo
    echo -e "${GREEN}Docker Structure Setup${NC}"
    echo -e "${GREEN}======================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Setting up Docker environment..."
    echo -e "${GRAY}  ${ARROW}${NC} Creating directory structure"
    echo -e "${GRAY}  ${ARROW}${NC} Generating Docker Compose configuration"

    # Create directory
    mkdir -p /root/kuma
    cd /root/kuma || {
        echo -e "${RED}${CROSS}${NC} Failed to change to /root/kuma directory"
        return 1
    }

    # Create Docker Compose
    cat > docker-compose.yml << COMPOSE_EOF
services:
  uptime-kuma:
    image: louislam/uptime-kuma:1
    container_name: uptime-kuma
    restart: always
    ports:
      - "127.0.0.1:3001:3001"
    volumes:
      - kuma_data:/app/data

  xray-checker:
    image: kutovoys/xray-checker
    container_name: xray-checker
    volumes:
      - ./config.json:/app/config.json
    restart: unless-stopped

volumes:
  kuma_data:
    external: true
COMPOSE_EOF

    echo -e "${GREEN}${CHECK}${NC} Docker structure setup completed!"
}

# Create configuration file
create_config_file() {
    echo
    echo -e "${CYAN}${INFO}${NC} Creating configuration file..."
    echo -e "${GRAY}  ${ARROW}${NC} Generating xray-checker configuration"
    echo -e "${GRAY}  ${ARROW}${NC} Adding VLESS links to configuration"

    # Start config file
    cat > config.json << CONFIG_START
{
  "provider": {
    "name": "uptime-kuma",
    "proxyStartPort": 19000,
    "interval": 40,
    "workers": 3,
    "checkIpService": "https://ifconfig.io",
    "configs": [
CONFIG_START

    # Add each VLESS link
    local total_links=${#VLESS_LINKS[@]}
    local current_link=1
    
    for link in "${VLESS_LINKS[@]}"; do
        cat >> config.json << CONFIG_LINK
      {
        "link": "$link",
        "monitorLink": "https://$KUMA_DOMAIN/api/push/MonitorID$current_link?status=up&msg=OK&ping="
      }
CONFIG_LINK
        
        # Add comma if not the last link
        if [ $current_link -lt $total_links ]; then
            echo "," >> config.json
        fi
        
        ((current_link++))
    done

    # Close config file
    cat >> config.json << CONFIG_END

    ]
  }
}
CONFIG_END

    echo -e "${GREEN}${CHECK}${NC} Configuration file created successfully!"
}

# Start services
start_services() {
    echo
    echo -e "${GREEN}Service Startup${NC}"
    echo -e "${GREEN}===============${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Starting Uptime Kuma services..."
    echo -e "${GRAY}  ${ARROW}${NC} Creating Docker volume"
    echo -e "${GRAY}  ${ARROW}${NC} Starting containers"

    # Create Docker volume
    docker volume create kuma_data > /dev/null 2>&1

    # Start services
    docker compose up -d > /dev/null 2>&1

    echo -e "${GREEN}${CHECK}${NC} Services startup completed!"
}

# Verify installation
verify_installation() {
    echo
    echo -e "${GREEN}Installation Verification${NC}"
    echo -e "${GREEN}=========================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Verifying installation..."
    echo -e "${GRAY}  ${ARROW}${NC} Waiting for services to initialize"
    
    # Wait for services to start
    sleep 10

    echo -e "${GRAY}  ${ARROW}${NC} Checking Docker containers"
    echo -e "${GRAY}  ${ARROW}${NC} Testing network connectivity"
    echo -e "${GRAY}  ${ARROW}${NC} Validating service endpoints"

    # Verify containers
    if docker ps | grep -q "uptime-kuma"; then
        echo -e "${GRAY}  ${ARROW}${NC} Uptime Kuma container: ${GREEN}Running${NC}"
    else
        echo -e "${GRAY}  ${ARROW}${NC} Uptime Kuma container: ${RED}Not running${NC}"
    fi

    if docker ps | grep -q "xray-checker"; then
        echo -e "${GRAY}  ${ARROW}${NC} Xray Checker container: ${GREEN}Running${NC}"
    else
        echo -e "${GRAY}  ${ARROW}${NC} Xray Checker container: ${RED}Not running${NC}"
    fi

    # Check port
    if ss -tlnp | grep -q 3001; then
        echo -e "${GRAY}  ${ARROW}${NC} Port 3001: ${GREEN}Listening${NC}"
    else
        echo -e "${GRAY}  ${ARROW}${NC} Port 3001: ${YELLOW}Not listening${NC}"
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
    
    echo -e "${CYAN}Configuration Summary:${NC}"
    echo -e "${WHITE}• https://$KUMA_DOMAIN${NC}"
    echo -e "${WHITE}• VLESS links configured: ${#VLESS_LINKS[@]}${NC}"
    echo -e "${WHITE}• Proxy start port: 19000${NC}"
    echo -e "${WHITE}• Check interval: 40 seconds${NC}"
    echo
    
    echo -e "${CYAN}Useful Commands:${NC}"
    echo -e "${WHITE}• Check logs: docker compose logs -f${NC}"
    echo -e "${WHITE}• Restart services: docker compose restart${NC}"
    echo -e "${WHITE}• Update config: nano /root/kuma/config.json${NC}"
}

#============================
# MAIN INSTALLATION FUNCTION
#============================

# Install Uptime Kuma
install_uptime_kuma() {
    echo
    # Get domain
    input_domain
    
    # Get VLESS links
    if ! input_vless_links; then
        echo -e "${RED}${CROSS}${NC} Installation cancelled - no VLESS links provided"
        return 1
    fi

    echo
    # Confirm configuration
    echo -e "${YELLOW}Configuration Summary:${NC}"
    echo -e "${WHITE}• Domain: $KUMA_DOMAIN${NC}"
    echo -e "${WHITE}• VLESS links: ${#VLESS_LINKS[@]}${NC}"
    echo
    echo -ne "${YELLOW}Continue with installation? (y/N): ${NC}"
    read -r CONFIRM

    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo
        echo -e "${CYAN}Installation cancelled.${NC}"
        return 0
    fi

    echo
    echo -e "${PURPLE}============================${NC}"
    echo -e "${NC}Uptime Kuma Installation${NC}"
    echo -e "${PURPLE}============================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Checking installation requirements..."
    echo -e "${GRAY}  ${ARROW}${NC} Verifying existing installation"
    echo -e "${GRAY}  ${ARROW}${NC} Checking system dependencies"

    # Check if already installed
    local kuma_installed=$(check_installation_status)
    
    if [ "$kuma_installed" = "true" ]; then
        echo -e "${RED}${CROSS}${NC} Uptime Kuma is already installed!"
        echo -e "${RED}Please uninstall it first if you want to reinstall.${NC}"
        return 1
    fi

    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}${CROSS}${NC} Docker is not installed!"
        echo -e "${RED}Please install Docker first.${NC}"
        return 1
    fi

    # Check Nginx
    if ! command -v nginx &> /dev/null; then
        echo -e "${RED}${CROSS}${NC} Nginx is not installed!"
        echo -e "${RED}Please install Nginx first.${NC}"
        return 1
    fi
    
    echo -e "${GREEN}${CHECK}${NC} System requirements validated!"

    set -e

    # Execute installation steps
    create_nginx_config
    create_docker_structure
    create_config_file
    start_services
    verify_installation
    display_installation_completion
}

#==========================
# UNINSTALLATION FUNCTIONS
#==========================

# Uninstall Uptime Kuma
uninstall_uptime_kuma() {
    echo
    # Confirmation
    echo -ne "${YELLOW}Are you sure you want to uninstall Uptime Kuma? (y/N): ${NC}"
    read -r CONFIRM

    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo
        echo -e "${CYAN}Uninstallation cancelled.${NC}"
        return 0
    fi

    echo
    echo -e "${PURPLE}===========================${NC}"
    echo -e "${NC}Uptime Kuma Uninstallation${NC}"
    echo -e "${PURPLE}===========================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Checking current installation status..."
    echo -e "${GRAY}  ${ARROW}${NC} Scanning for Uptime Kuma components"
    echo -e "${GRAY}  ${ARROW}${NC} Identifying services to remove"

    # Check if installed
    local kuma_installed=$(check_installation_status)
    
    if [ "$kuma_installed" != "true" ]; then
        echo -e "${YELLOW}Uptime Kuma is not installed on this system.${NC}"
        return 0
    fi

    echo -e "${GREEN}${CHECK}${NC} Installation status check completed!"
    echo

    echo -e "${GREEN}Docker Services Removal${NC}"
    echo -e "${GREEN}=======================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Removing Docker services..."
    echo -e "${GRAY}  ${ARROW}${NC} Stopping running containers"
    echo -e "${GRAY}  ${ARROW}${NC} Removing containers and volumes"

    # Stop and remove containers
    cd /root/kuma 2>/dev/null
    if [ -f "docker-compose.yml" ]; then
        docker compose down > /dev/null 2>&1
    fi

    # Remove Docker volume
    docker volume rm kuma_data > /dev/null 2>&1 || true

    echo -e "${GREEN}${CHECK}${NC} Docker services removal completed!"
    echo

    echo -e "${GREEN}File System Cleanup${NC}"
    echo -e "${GREEN}===================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Removing installation files..."
    echo -e "${GRAY}  ${ARROW}${NC} Removing installation directory"
    echo -e "${GRAY}  ${ARROW}${NC} Cleaning up configuration files"

    # Remove installation directory
    if [ -d "/root/kuma" ]; then
        rm -rf /root/kuma
    fi

    echo -e "${GREEN}${CHECK}${NC} File system cleanup completed!"
    echo

    echo -e "${GREEN}Web Server Configuration${NC}"
    echo -e "${GREEN}========================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Removing web server configuration..."
    echo -e "${GRAY}  ${ARROW}${NC} Removing Nginx configuration"
    echo -e "${GRAY}  ${ARROW}${NC} Reloading web server"

    # Remove Nginx configuration
    if [ -f "/etc/nginx/conf.d/kuma.conf" ]; then
        rm -f /etc/nginx/conf.d/kuma.conf
    fi
    
    # Reload Nginx
    if nginx -t > /dev/null 2>&1; then
        systemctl reload nginx > /dev/null 2>&1 || true
    fi

    echo -e "${GREEN}${CHECK}${NC} Web server configuration cleanup completed!"
    echo

    echo -e "${PURPLE}===========================${NC}"
    echo -e "${GREEN}${CHECK}${NC} Uninstallation complete!"
    echo -e "${PURPLE}===========================${NC}"
    echo
    echo -e "${CYAN}All Uptime Kuma components have been successfully removed.${NC}"
}

#================
# MENU FUNCTIONS
#================

# Show main menu
show_main_menu() {
    local kuma_installed=$(check_installation_status)
    
    echo -e "${CYAN}Please select an action:${NC}"
    echo
    if [ "$kuma_installed" = "true" ]; then
        echo -e "${BLUE}1.${NC} Show Status"
        echo -e "${YELLOW}2.${NC} Uninstall"
        echo -e "${RED}3.${NC} Exit"
    else
        echo -e "${GREEN}1.${NC} Install"
        echo -e "${YELLOW}2.${NC} Uninstall"
        echo -e "${RED}3.${NC} Exit"
    fi
    echo
}

# Handle user choice
handle_user_choice() {
    local kuma_installed=$(check_installation_status)
    
    while true; do
        if [ "$kuma_installed" = "true" ]; then
            echo -ne "${CYAN}Enter your choice (1-3): ${NC}"
            read CHOICE
        else
            echo -ne "${CYAN}Enter your choice (1-3): ${NC}"
            read CHOICE
        fi
        
        case $CHOICE in
            1)
                if [ "$kuma_installed" = "true" ]; then
                    show_status
                else
                    install_uptime_kuma
                fi
                break
                ;;
            2)
                uninstall_uptime_kuma
                break
                ;;
            3)
                echo -e "${CYAN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}${CROSS}${NC} Invalid choice. Please enter 1, 2, or 3."
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
    echo -e "${PURPLE}===============================${NC}"
    echo -e "${NC}UPTIME KUMA MONITORING MANAGER${NC}"
    echo -e "${PURPLE}===============================${NC}"
    echo

    # Show menu and handle user choice
    show_main_menu
    handle_user_choice
    echo
}

# Execute main function
main
