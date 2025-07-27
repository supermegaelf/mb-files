#!/bin/bash

#=================================
# MARZBAN NODE MONITORING MANAGER
#=================================

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
ACTION=""
PANEL_IP=""

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

# Validate IP format
validate_ip_format() {
    if [[ ! $PANEL_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo
        echo -ne "${YELLOW}Warning: IP format looks unusual. Continue anyway? (y/N): ${NC}"
        read -r CONTINUE
        if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
            echo
            echo -e "${CYAN}Installation cancelled.${NC}"
            exit 0
        fi
    fi
}

#============================
# INPUT VALIDATION FUNCTIONS
#============================

# Input panel IP
input_panel_ip() {
    echo
    echo -ne "${CYAN}Marzban Panel IP address: ${NC}"
    read PANEL_IP

    while [[ -z "$PANEL_IP" ]]; do
        echo -e "${RED}${CROSS}${NC} Panel IP cannot be empty!"
        echo -ne "${CYAN}Panel IP: ${NC}"
        read PANEL_IP
    done
    
    validate_ip_format
}

#================
# MENU FUNCTIONS
#================

# Show main menu
show_main_menu() {
    echo -e "${CYAN}Please select an action:${NC}"
    echo
    echo -e "${GREEN}1.${NC} Install"
    echo -e "${YELLOW}2.${NC} Uninstall"
    echo -e "${RED}3.${NC} Exit"
    echo
}

# Handle user choice
handle_user_choice() {
    while true; do
        echo -ne "${CYAN}Enter your choice (1-3): ${NC}"
        read CHOICE
        case $CHOICE in
            1)
                ACTION="install"
                break
                ;;
            2)
                ACTION="uninstall"
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

# Process command line arguments
process_arguments() {
    if [ "$1" = "uninstall" ] || [ "$1" = "--uninstall" ] || [ "$1" = "-u" ]; then
        ACTION="uninstall"
    elif [ "$1" = "install" ] || [ "$1" = "--install" ] || [ "$1" = "-i" ]; then
        ACTION="install"
    else
        show_main_menu
        handle_user_choice
    fi
}

#==========================
# UNINSTALLATION FUNCTIONS
#==========================

# Check if Node Exporter is installed
check_node_exporter_installation() {
    if [ ! -f "/usr/local/bin/node_exporter" ]; then
        echo -e "${YELLOW}Node Exporter is not installed on this system.${NC}"
        exit 0
    fi
}

# Remove Node Exporter service
remove_node_exporter_service() {
    echo -e "${CYAN}${INFO}${NC} Removing Node Exporter service..."
    echo -e "${GRAY}  ${ARROW}${NC} Stopping Node Exporter service"
    echo -e "${GRAY}  ${ARROW}${NC} Disabling Node Exporter service"
    echo -e "${GRAY}  ${ARROW}${NC} Removing service files"

    systemctl stop node_exporter > /dev/null 2>&1 || true
    systemctl disable node_exporter > /dev/null 2>&1 || true

    if [ -f "/etc/systemd/system/node_exporter.service" ]; then
        rm -f /etc/systemd/system/node_exporter.service
        systemctl daemon-reload > /dev/null 2>&1
    fi

    echo -e "${GREEN}${CHECK}${NC} Node Exporter service removed!"
}

# Remove Node Exporter files
remove_node_exporter_files() {
    echo
    echo -e "${CYAN}${INFO}${NC} Removing Node Exporter files..."
    echo -e "${GRAY}  ${ARROW}${NC} Removing binary files"
    echo -e "${GRAY}  ${ARROW}${NC} Removing system user"

    if [ -f "/usr/local/bin/node_exporter" ]; then
        rm -f /usr/local/bin/node_exporter
    fi

    # Remove user
    if id "node_exporter" &>/dev/null; then
        userdel node_exporter > /dev/null 2>&1 || true
    fi

    echo -e "${GREEN}${CHECK}${NC} Node Exporter files removed!"
}

# Remove UFW rules
remove_ufw_rules() {
    echo
    echo -e "${CYAN}${INFO}${NC} Removing UFW rules..."
    echo -e "${GRAY}  ${ARROW}${NC} Scanning for Node Exporter rules"
    echo -e "${GRAY}  ${ARROW}${NC} Removing firewall rules"
    echo -e "${GRAY}  ${ARROW}${NC} Cleaning up port 9100 access"

    # Method 1: Try to remove rules by rule number
    UFW_RULES=$(ufw status numbered | grep -E "9100.*Panel Prometheus" | awk '{print $1}' | sed 's/\[//g' | sed 's/\]//g' | sort -nr)
    
    if [ -n "$UFW_RULES" ]; then
        for rule_num in $UFW_RULES; do
            echo "y" | ufw delete $rule_num > /dev/null 2>&1 || true
        done
    else
        # Method 2: Try to remove by pattern if numbered approach fails
        ufw status numbered | grep -E "9100.*tcp" | while read line; do
            if echo "$line" | grep -q "9100"; then
                rule_num=$(echo "$line" | awk '{print $1}' | sed 's/\[//g' | sed 's/\]//g')
                if [ -n "$rule_num" ]; then
                    echo "y" | ufw delete $rule_num > /dev/null 2>&1 || true
                fi
            fi
        done
    fi
    
    # Method 3: Generic fallback
    if ufw status | grep -q ":9100"; then
        ufw delete allow 9100 > /dev/null 2>&1 || true
    fi

    echo -e "${GREEN}${CHECK}${NC} UFW rules removed!"
}

# Display uninstall completion
display_uninstall_completion() {
    echo

    echo -e "${PURPLE}===========================${NC}"
    echo -e "${GREEN}${CHECK}${NC} Uninstallation complete!"
    echo -e "${PURPLE}===========================${NC}"
    echo
    echo -e "${CYAN}Node Exporter has been successfully removed.${NC}"
}

# Main uninstall function
uninstall_node_exporter() {
    echo
    # Confirmation
    echo -ne "${YELLOW}Are you sure you want to uninstall Node Exporter? (y/N): ${NC}"
    read -r CONFIRM

    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo
        echo -e "${CYAN}Uninstallation cancelled.${NC}"
        exit 0
    fi

    echo
    echo -e "${PURPLE}=============================${NC}"
    echo -e "${NC}Node Exporter Uninstallation${NC}"
    echo -e "${PURPLE}=============================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Checking current installation status..."
    echo -e "${GRAY}  ${ARROW}${NC} Verifying Node Exporter installation"
    echo -e "${GRAY}  ${ARROW}${NC} Scanning system components"

    check_node_exporter_installation
    echo -e "${GREEN}${CHECK}${NC} Installation verification completed!"

    echo
    echo -e "${GREEN}Node Exporter Removal${NC}"
    echo -e "${GREEN}======================${NC}"
    echo

    remove_node_exporter_service
    remove_node_exporter_files
    remove_ufw_rules
    display_uninstall_completion
}

#========================
# INSTALLATION FUNCTIONS
#========================

# Check for existing installation
check_existing_installation() {
    if [ -f "/usr/local/bin/node_exporter" ]; then
        echo -e "${YELLOW}Node Exporter appears to be already installed.${NC}"
        echo
        echo -ne "${YELLOW}Do you want to reinstall? (y/N): ${NC}"
        read -r REINSTALL
        
        if [[ ! "$REINSTALL" =~ ^[Yy]$ ]]; then
            echo
            echo -e "${CYAN}Installation cancelled.${NC}"
            exit 0
        fi
        
        echo
        echo -e "${YELLOW}Proceeding with reinstallation...${NC}"
    fi
}

# Download and install Node Exporter
download_and_install_node_exporter() {
    echo
    echo -e "${PURPLE}=============================${NC}"
    echo -e "${WHITE}Node Monitoring Installation${NC}"
    echo -e "${PURPLE}=============================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Downloading and installing Node Exporter..."
    echo -e "${GRAY}  ${ARROW}${NC} Downloading Node Exporter v1.9.1"
    echo -e "${GRAY}  ${ARROW}${NC} Extracting binary files"
    echo -e "${GRAY}  ${ARROW}${NC} Installing to /usr/local/bin"

    # Download and install Node Exporter
    wget -q https://github.com/prometheus/node_exporter/releases/download/v1.9.1/node_exporter-1.9.1.linux-amd64.tar.gz > /dev/null 2>&1
    tar xvf node_exporter-1.9.1.linux-amd64.tar.gz > /dev/null 2>&1
    cp node_exporter-1.9.1.linux-amd64/node_exporter /usr/local/bin/
    rm -rf node_exporter-1.9.1.linux-amd64*

    echo -e "${GREEN}${CHECK}${NC} Node Exporter installation completed!"
}

# Create user and service
create_user_and_service() {
    echo
    echo -e "${CYAN}${INFO}${NC} Creating user and service..."
    echo -e "${GRAY}  ${ARROW}${NC} Creating node_exporter system user"
    echo -e "${GRAY}  ${ARROW}${NC} Setting file permissions"
    echo -e "${GRAY}  ${ARROW}${NC} Creating systemd service"

    # Create user and service
    useradd --no-create-home --shell /bin/false node_exporter > /dev/null 2>&1 || true
    chown node_exporter:node_exporter /usr/local/bin/node_exporter

    # Create systemd service
    cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter --web.listen-address=0.0.0.0:9100
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${GREEN}${CHECK}${NC} User and service created successfully!"
}

# Start Node Exporter service
start_node_exporter_service() {
    echo
    echo -e "${CYAN}${INFO}${NC} Starting Node Exporter service..."
    echo -e "${GRAY}  ${ARROW}${NC} Reloading systemd daemon"
    echo -e "${GRAY}  ${ARROW}${NC} Enabling Node Exporter service"
    echo -e "${GRAY}  ${ARROW}${NC} Starting Node Exporter service"

    systemctl daemon-reload > /dev/null 2>&1
    systemctl enable node_exporter > /dev/null 2>&1
    systemctl start node_exporter > /dev/null 2>&1

    echo -e "${GREEN}${CHECK}${NC} Node Exporter service started successfully!"
}

# Configure firewall
configure_firewall() {
    echo
    echo -e "${GREEN}Firewall Configuration${NC}"
    echo -e "${GREEN}======================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Configuring UFW firewall..."
    echo -e "${GRAY}  ${ARROW}${NC} Adding rule for panel access"
    echo -e "${GRAY}  ${ARROW}${NC} Allowing port 9100 from ${PANEL_IP}"
    echo -e "${GRAY}  ${ARROW}${NC} Configuring Node Exporter access"

    # Configure UFW to allow Panel access
    ufw allow from $PANEL_IP to any port 9100 proto tcp comment "Panel Prometheus access to Node Exporter" > /dev/null 2>&1

    echo -e "${GREEN}${CHECK}${NC} Firewall configuration completed!"
}

# Verify installation
verify_installation() {
    echo
    echo -e "${GREEN}Installation Verification${NC}"
    echo -e "${GREEN}=========================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Verifying Node Exporter installation..."
    echo -e "${GRAY}  ${ARROW}${NC} Waiting for services to initialize"
    
    # Wait for service to start
    sleep 5

    echo -e "${GRAY}  ${ARROW}${NC} Checking Node Exporter service status"
    echo -e "${GRAY}  ${ARROW}${NC} Testing metrics endpoint"
    echo -e "${GRAY}  ${ARROW}${NC} Validating accessibility"

    # Verify Node Exporter status
    if systemctl is-active --quiet node_exporter; then
        echo -e "${GRAY}  ${ARROW}${NC} Node Exporter: ${GREEN}Running${NC}"
    else
        echo -e "${RED}${CROSS}${NC} Node Exporter failed to start"
        echo -e "${CYAN}Check logs with: journalctl -u node_exporter -f${NC}"
        exit 1
    fi

    # Test if metrics endpoint is accessible
    if curl -s --max-time 5 http://localhost:9100/metrics | head -n 5 > /dev/null 2>&1; then
        echo -e "${GRAY}  ${ARROW}${NC} Metrics endpoint: ${GREEN}Accessible${NC}"
    else
        echo -e "${GRAY}  ${ARROW}${NC} Metrics endpoint: ${YELLOW}Warning - not accessible locally${NC}"
    fi

    echo -e "${GREEN}${CHECK}${NC} Installation verification completed!"
}

# Display installation completion
display_installation_completion() {
    echo

    echo -e "${PURPLE}=========================${NC}"
    echo -e "${GREEN}${CHECK}${NC} Installation complete!"
    echo -e "${PURPLE}=========================${NC}"
    echo

    echo -e "${CYAN}Configuration Summary:${NC}"
    echo -e "${WHITE}• Panel IP allowed: $PANEL_IP${NC}"
    echo
    
    echo -e "${CYAN}Test Commands:${NC}"
    echo -e "${WHITE}• Test connectivity: curl http://$(hostname -I | awk '{print $1}'):9100/metrics${NC}"
    echo -e "${WHITE}• View logs: journalctl -u node_exporter -f${NC}"
}

# Main install function
install_node_exporter() {
    check_existing_installation
    
    # Get panel IP
    input_panel_ip

    set -e

    download_and_install_node_exporter
    create_user_and_service
    start_node_exporter_service
    configure_firewall
    verify_installation
    display_installation_completion
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
    echo -e "${PURPLE}================================${NC}"
    echo -e "${NC}MARZBAN NODE MONITORING MANAGER${NC}"
    echo -e "${PURPLE}================================${NC}"
    echo

    # Process arguments or show menu
    process_arguments "$1"

    # Execute action
    if [ "$ACTION" = "uninstall" ]; then
        uninstall_node_exporter
    else
        install_node_exporter
    fi
    
    echo
}

# Execute main function
main
