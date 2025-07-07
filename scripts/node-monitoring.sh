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

# Marzban Node Monitoring Setup Script
echo
echo -e "${PURPLE}========================${NC}"
echo -e "${NC}MARZBAN NODE MONITORING${NC}"
echo -e "${PURPLE}========================${NC}"
echo

# Check if script is run with parameters
if [ "$1" = "uninstall" ] || [ "$1" = "--uninstall" ] || [ "$1" = "-u" ]; then
   ACTION="uninstall"
elif [ "$1" = "install" ] || [ "$1" = "--install" ] || [ "$1" = "-i" ]; then
   ACTION="install"
else
   # Interactive menu
   echo -e "${CYAN}Please select an action:${NC}"
   echo
   echo -e "${GREEN}1.${NC} Install"
   echo -e "${YELLOW}2.${NC} Uninstall"
   echo -e "${RED}3.${NC} Exit"
   echo
   
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
               echo -e "${RED}Invalid choice. Please enter 1, 2, or 3.${NC}"
               ;;
       esac
   done
fi

# Uninstall function
if [ "$ACTION" = "uninstall" ]; then
   echo
   echo -e "${PURPLE}==========================${NC}"
   echo -e "${NC}Node Exporter Uninstaller${NC}"
   echo -e "${PURPLE}==========================${NC}"
   echo

   # Check if Node Exporter is installed
   if [ ! -f "/usr/local/bin/node_exporter" ]; then
       echo -e "${YELLOW}Node Exporter is not installed on this system.${NC}"
       echo
       exit 0
   fi

   # Confirmation
   echo -ne "${YELLOW}Are you sure you want to uninstall Node Exporter? (y/N): ${NC}"
   read -r CONFIRM

   if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
       echo
       echo -e "${CYAN}Uninstallation cancelled.${NC}"
       echo
       exit 0
   fi

   echo
   echo -e "${GREEN}=======================${NC}"
   echo -e "${NC}Removing Node Exporter${NC}"
   echo -e "${GREEN}=======================${NC}"
   echo

   # Stop and remove Node Exporter
   echo "Stopping Node Exporter service..."
   systemctl stop node_exporter 2>/dev/null && echo -e "${GREEN}✓${NC} Node Exporter stopped" || echo "ℹ Node Exporter was not running"
   systemctl disable node_exporter 2>/dev/null && echo -e "${GREEN}✓${NC} Node Exporter disabled" || echo "ℹ Node Exporter was not enabled"

   echo
   echo "Removing Node Exporter files..."
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

   # Remove UFW rules - improved version for Marzban
   echo
   echo "Removing UFW rules..."
   
   # Method 1: Try to remove rules by rule number
   UFW_RULES=$(ufw status numbered | grep -E "9100.*Panel Prometheus" | awk '{print $1}' | sed 's/\[//g' | sed 's/\]//g' | sort -nr)
   
   if [ -n "$UFW_RULES" ]; then
       for rule_num in $UFW_RULES; do
           echo "Removing UFW rule #$rule_num..."
           echo "y" | ufw delete $rule_num 2>/dev/null && echo -e "${GREEN}✓${NC} UFW rule #$rule_num removed" || echo "ℹ Could not remove rule #$rule_num"
       done
   else
       # Method 2: Try to remove by pattern if numbered approach fails
       echo
       echo "Attempting to remove UFW rules by pattern..."
       ufw status numbered | grep -E "9100.*tcp" | while read line; do
           if echo "$line" | grep -q "9100"; then
               # Extract rule number
               rule_num=$(echo "$line" | awk '{print $1}' | sed 's/\[//g' | sed 's/\]//g')
               if [ -n "$rule_num" ]; then
                   echo "Removing UFW rule #$rule_num..."
                   echo "y" | ufw delete $rule_num 2>/dev/null && echo -e "${GREEN}✓${NC} UFW rule #$rule_num removed" || echo "ℹ Could not remove rule #$rule_num"
               fi
           fi
       done
   fi
   
   # Method 3: Generic fallback
   if ufw status | grep -q ":9100"; then
       echo "Attempting generic UFW rule removal..."
       ufw delete allow 9100 2>/dev/null && echo -e "${GREEN}✓${NC} Generic UFW rule removed" || echo "ℹ Generic UFW rule not found"
   fi

   echo
   echo -e "${GREEN}==========================================${NC}"
   echo -e "${GREEN}✓${NC} Node Exporter uninstalled successfully!"
   echo -e "${GREEN}==========================================${NC}"
   echo
   exit 0
fi

# Installation process
echo
echo -e "${PURPLE}===========================${NC}"
echo -e "${NC}Node Exporter Installation${NC}"
echo -e "${PURPLE}===========================${NC}"
echo

# Check if Node Exporter is already installed
if [ -f "/usr/local/bin/node_exporter" ]; then
   echo -e "${YELLOW}Node Exporter appears to be already installed.${NC}"
   echo
   echo -ne "${YELLOW}Do you want to reinstall? (y/N): ${NC}"
   read -r REINSTALL
   echo
   
   if [[ ! "$REINSTALL" =~ ^[Yy]$ ]]; then
       echo -e "${CYAN}Installation cancelled.${NC}"
       echo
       exit 0
   fi
   
   echo -e "${YELLOW}Proceeding with reinstallation...${NC}"
   echo
fi

# Get Marzban Panel IP for UFW rule
echo -ne "${CYAN}Marzban Panel IP address: ${NC}"
read PANEL_IP

while [[ -z "$PANEL_IP" ]]; do
    echo -e "${RED}Panel IP cannot be empty!${NC}"
    echo -ne "${CYAN}Panel IP: ${NC}"
    read PANEL_IP
done

# Validate IP format (basic check)
if [[ ! $PANEL_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo -ne "${YELLOW}Warning: IP format looks unusual. Continue anyway? (y/N): ${NC}"
    read -r CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}Installation cancelled.${NC}"
        exit 0
    fi
fi

set -e

echo
echo -e "${GREEN}============================${NC}"
echo -e "${NC}1. Installing Node Exporter${NC}"
echo -e "${GREEN}============================${NC}"
echo

# Download and install Node Exporter
echo "Downloading Node Exporter..."
echo
wget -q https://github.com/prometheus/node_exporter/releases/download/v1.9.1/node_exporter-1.9.1.linux-amd64.tar.gz
tar xvf node_exporter-1.9.1.linux-amd64.tar.gz > /dev/null
sudo cp node_exporter-1.9.1.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-1.9.1.linux-amd64*

# Create user and service
echo "Creating Node Exporter user and service..."
sudo useradd --no-create-home --shell /bin/false node_exporter 2>/dev/null || true
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter

# Create systemd service
sudo tee /etc/systemd/system/node_exporter.service > /dev/null << 'EOF'
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

# Start Node Exporter
systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

echo
echo -e "${GREEN}----------------------------------------${NC}"
echo -e "${GREEN}✓${NC} Node Exporter installation completed!"
echo -e "${GREEN}----------------------------------------${NC}"
echo

echo -e "${GREEN}========================${NC}"
echo -e "${NC}2. Configuring Firewall${NC}"
echo -e "${GREEN}========================${NC}"
echo

# Configure UFW to allow Panel access
echo "Adding UFW rule..."
ufw allow from $PANEL_IP to any port 9100 proto tcp comment "Panel Prometheus access to Node Exporter" > /dev/null

echo
echo -e "${GREEN}------------------------------${NC}"
echo -e "${GREEN}✓${NC} Firewall configuration completed!"
echo -e "${GREEN}------------------------------${NC}"
echo

echo -e "${GREEN}======================${NC}"
echo -e "${NC}3. Final verification${NC}"
echo -e "${GREEN}======================${NC}"
echo

# Wait for service to start
echo "Waiting for services to start..."
sleep 5

# Verify Node Exporter status
echo "Checking Node Exporter status..."
if systemctl is-active --quiet node_exporter; then
   echo -e "${GREEN}✓${NC} Node Exporter is running"
else
   echo -e "${RED}✗${NC} Node Exporter failed to start"
   echo "Check logs with: journalctl -u node_exporter -f"
   exit 1
fi

# Test if metrics endpoint is accessible
echo "Testing metrics endpoint..."
if curl -s --max-time 5 http://localhost:9100/metrics | head -n 5 > /dev/null; then
   echo -e "${GREEN}✓${NC} Node Exporter metrics are accessible"
else
   echo -e "${YELLOW}⚠ Could not access metrics endpoint locally${NC}"
fi

echo
echo -e "${GREEN}--------------------------------${NC}"
echo -e "${GREEN}✓${NC} Final verification completed!"
echo -e "${GREEN}--------------------------------${NC}"
echo
echo -e "${GREEN}===============================================${NC}"
echo -e "${GREEN}✓${NC} Node Exporter installation completed!"
echo -e "${GREEN}===============================================${NC}"
echo
echo -e "${CYAN}Configuration Summary:${NC}"
echo -e "Panel IP allowed: ${WHITE}$PANEL_IP${NC}"
echo
echo -e "${CYAN}Test connectivity from Panel:${NC}"
echo -e "${WHITE}curl http://$(hostname -I | awk '{print $1}'):9100/metrics${NC}"
echo
echo -e "${CYAN}Logs:${NC}"
echo -e "${NC}journalctl -u node_exporter -f${NC}"
echo
