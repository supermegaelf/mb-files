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

MYSQL_USER=""
MYSQL_PASSWORD=""
TG_BOT_TOKEN=""
TG_CHAT_ID=""

echo
echo -e "${PURPLE}===============${NC}"
echo -e "${NC}MARZBAN BACKUP${NC}"
echo -e "${PURPLE}===============${NC}"
echo

if [ -z "$MYSQL_USER" ] || [ -z "$MYSQL_PASSWORD" ] || [ -z "$TG_BOT_TOKEN" ] || [ -z "$TG_CHAT_ID" ]; then
    echo -ne "${CYAN}MySQL username (default is marzban, press Enter to use default): ${NC}"
    read MYSQL_USER
    MYSQL_USER=${MYSQL_USER:-marzban}
    echo -ne "${CYAN}MySQL password: ${NC}"
    read -s MYSQL_PASSWORD
    echo
    echo -ne "${CYAN}Telegram Bot Token: ${NC}"
    read TG_BOT_TOKEN
    echo -ne "${CYAN}Telegram Chat ID: ${NC}"
    read TG_CHAT_ID

    if [ -z "$MYSQL_USER" ]; then
        echo -e "${RED}Error: MySQL username cannot be empty${NC}"
        exit 1
    fi
    if [ -z "$MYSQL_PASSWORD" ]; then
        echo -e "${RED}Error: MySQL password cannot be empty${NC}"
        exit 1
    fi
    if [[ ! "$TG_BOT_TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
        echo -e "${RED}Error: Invalid Telegram Bot Token format${NC}"
        exit 1
    fi
    if [[ ! "$TG_CHAT_ID" =~ ^-?[0-9]+$ ]]; then
        echo -e "${RED}Error: Invalid Telegram Chat ID format${NC}"
        exit 1
    fi

    sed -i "s/MYSQL_USER=\"\"/MYSQL_USER=\"$MYSQL_USER\"/" "$0"
    sed -i "s/MYSQL_PASSWORD=\"\"/MYSQL_PASSWORD=\"$MYSQL_PASSWORD\"/" "$0"
    sed -i "s/TG_BOT_TOKEN=\"\"/TG_BOT_TOKEN=\"$TG_BOT_TOKEN\"/" "$0"
    sed -i "s/TG_CHAT_ID=\"\"/TG_CHAT_ID=\"$TG_CHAT_ID\"/" "$0"

    if ! grep -q "/root/scripts/tg-backup.sh" /etc/crontab; then
        echo "0 */1 * * * root /bin/bash /root/scripts/tg-backup.sh >/dev/null 2>&1" | tee -a /etc/crontab
    fi
    
    echo
    echo -e "${GREEN}✓${NC} Configuration saved successfully!"
    echo
fi

if [ -z "$MYSQL_USER" ]; then
    echo -e "${RED}Error: MySQL username cannot be empty${NC}"
    exit 1
fi

if [ -z "$MYSQL_PASSWORD" ]; then
    echo -e "${RED}Error: MySQL password cannot be empty${NC}"
    exit 1
fi

if [[ ! "$TG_BOT_TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
    echo -e "${RED}Error: Invalid Telegram Bot Token format${NC}"
    exit 1
fi

if [[ ! "$TG_CHAT_ID" =~ ^-?[0-9]+$ ]]; then
    echo -e "${RED}Error: Invalid Telegram Chat ID format${NC}"
    exit 1
fi

echo -e "${GREEN}======================${NC}"
echo -e "${NC}1. System preparation${NC}"
echo -e "${GREEN}======================${NC}"
echo

TEMP_DIR=$(mktemp -d)
if [ ! -d "$TEMP_DIR" ]; then
    echo -e "${RED}Error: Failed to create temporary directory${NC}"
    exit 1
fi
BACKUP_FILE="$TEMP_DIR/backup-marzban.tar.gz"

echo -e "${GREEN}✓${NC} Temporary directory created: $TEMP_DIR"

echo
echo -e "${GREEN}--------------------------------${NC}"
echo -e "${GREEN}✓${NC} System preparation completed!"
echo -e "${GREEN}--------------------------------${NC}"
echo

echo -e "${GREEN}================================${NC}"
echo -e "${NC}2. Checking Docker containers${NC}"
echo -e "${GREEN}================================${NC}"
echo

MYSQL_CONTAINER_NAME="marzban-mariadb-1"
if ! docker ps -q -f name="$MYSQL_CONTAINER_NAME" | grep -q .; then
    echo -e "${RED}Error: Container $MYSQL_CONTAINER_NAME is not running${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo -e "${GREEN}✓${NC} Container $MYSQL_CONTAINER_NAME is running"

SHOP_CONTAINER_NAME="marzban-shop-db-1"
if docker ps -q -f name="$SHOP_CONTAINER_NAME" | grep -q .; then
    echo -e "${GREEN}✓${NC} Container $SHOP_CONTAINER_NAME is running"
else
    echo -e "${YELLOW}Warning: Container $SHOP_CONTAINER_NAME not found, skipping shop database dump${NC}"
fi

echo
echo -e "${GREEN}-------------------------------------${NC}"
echo -e "${GREEN}✓${NC} Docker containers check completed!"
echo -e "${GREEN}-------------------------------------${NC}"
echo

echo -e "${GREEN}=============================${NC}"
echo -e "${NC}3. Creating database backup${NC}"
echo -e "${GREEN}=============================${NC}"
echo

databases_marzban=$(docker exec $MYSQL_CONTAINER_NAME mariadb -h 127.0.0.1 --user="$MYSQL_USER" --password="$MYSQL_PASSWORD" -e "SHOW DATABASES;" 2>/tmp/marzban_error.log | tr -d "| " | grep -v Database)
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to retrieve marzban databases${NC}"
    cat /tmp/marzban_error.log
    rm -rf "$TEMP_DIR" /tmp/marzban_error.log
    exit 1
fi
rm -f /tmp/marzban_error.log

echo -e "${GREEN}✓${NC} Marzban databases retrieved"

databases_shop=""
if docker ps -q -f name="$SHOP_CONTAINER_NAME" | grep -q .; then
    databases_shop=$(docker exec $SHOP_CONTAINER_NAME mariadb -h 127.0.0.1 --user="$MYSQL_USER" --password="$MYSQL_PASSWORD" -e "SHOW DATABASES;" 2>/tmp/shop_error.log | tr -d "| " | grep -v Database)
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to retrieve shop databases${NC}"
        cat /tmp/shop_error.log
        rm -rf "$TEMP_DIR" /tmp/shop_error.log
        exit 1
    fi
    rm -f /tmp/shop_error.log
    echo -e "${GREEN}✓${NC} Shop databases retrieved"
fi

mkdir -p /var/lib/marzban/mysql/db-backup/
echo -e "${GREEN}✓${NC} Database backup directory created"

echo "Creating database backups..."
for db in $databases_marzban; do
    if [[ "$db" == "marzban" ]]; then
        docker exec $MYSQL_CONTAINER_NAME mariadb-dump -h 127.0.0.1 --force --opt --user="$MYSQL_USER" --password="$MYSQL_PASSWORD" --databases $db > /var/lib/marzban/mysql/db-backup/$db.sql
        echo -e "${GREEN}✓${NC} Marzban database backup created"
    fi
done

if [ -n "$databases_shop" ]; then
    for db in $databases_shop; do
        if [[ "$db" == "shop" ]]; then
            docker exec $SHOP_CONTAINER_NAME mariadb-dump -h 127.0.0.1 --force --opt --user="$MYSQL_USER" --password="$MYSQL_PASSWORD" --databases $db > /var/lib/marzban/mysql/db-backup/$db.sql
            echo -e "${GREEN}✓${NC} Shop database backup created"
        fi
    done
fi

echo
echo -e "${GREEN}--------------------------------------${NC}"
echo -e "${GREEN}✓${NC} Database backup creation completed!"
echo -e "${GREEN}--------------------------------------${NC}"
echo

echo -e "${GREEN}===========================${NC}"
echo -e "${NC}4. Creating backup archive${NC}"
echo -e "${GREEN}===========================${NC}"
echo

echo "Creating backup archive..."
tar --exclude='/var/lib/marzban/mysql/*' \
    --exclude='/var/lib/marzban/logs/*' \
    --exclude='/var/lib/marzban/access.log*' \
    --exclude='/var/lib/marzban/error.log*' \
    --exclude='/var/lib/marzban/xray-core/*' \
    -cf "$TEMP_DIR/backup-marzban.tar" \
    -C / \
    /opt/marzban/.env \
    /opt/marzban/ \
    /var/lib/marzban/ \
    $([ -f /root/marzban-shop/.env ] && echo "/root/marzban-shop/.env")

echo -e "${GREEN}✓${NC} Configuration files archived"

tar -rf "$TEMP_DIR/backup-marzban.tar" -C / /var/lib/marzban/mysql/db-backup/*
echo -e "${GREEN}✓${NC} Database backup added to archive"

gzip "$TEMP_DIR/backup-marzban.tar"
echo -e "${GREEN}✓${NC} Archive compressed successfully"

echo
echo -e "${GREEN}-------------------------------------${NC}"
echo -e "${GREEN}✓${NC} Backup archive creation completed!"
echo -e "${GREEN}-------------------------------------${NC}"
echo

echo -e "${GREEN}=======================${NC}"
echo -e "${NC}5. Sending to Telegram${NC}"
echo -e "${GREEN}=======================${NC}"
echo

echo "Sending backup to Telegram..."
curl -F chat_id="$TG_CHAT_ID" \
     -F document=@"$BACKUP_FILE" \
     https://api.telegram.org/bot$TG_BOT_TOKEN/sendDocument

# Check if upload was successful
if [ $? -eq 0 ]; then
    echo
    echo -e "${GREEN}✓${NC} Backup successfully sent to Telegram"
    # Clean up database backup directory
    rm -rf /var/lib/marzban/mysql/db-backup/*
    echo -e "${GREEN}✓${NC} Database backup files cleaned up"
else
    echo
    echo -e "${RED}✗${NC} Failed to send backup to Telegram"
fi

echo
echo -e "${GREEN}-----------------------------${NC}"
echo -e "${GREEN}✓${NC} Telegram upload completed!"
echo -e "${GREEN}-----------------------------${NC}"
echo

echo -e "${GREEN}===================${NC}"
echo -e "${NC}6. Cleanup process${NC}"
echo -e "${GREEN}===================${NC}"
echo

# Clean up temporary files
rm -rf "$TEMP_DIR"
echo -e "${GREEN}✓${NC} Temporary files cleaned up"

echo
echo -e "${GREEN}-----------------------------${NC}"
echo -e "${GREEN}✓${NC} Cleanup process completed!"
echo -e "${GREEN}-----------------------------${NC}"
echo

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}✓${NC} Backup process completed successfully!"
echo -e "${GREEN}=========================================${NC}"
echo
echo -e "${CYAN}Backup Information:${NC}"
echo -e "Archive name: ${WHITE}backup-marzban.tar.gz${NC}"
echo -e "MySQL User: ${WHITE}$MYSQL_USER${NC}"
echo -e "Telegram Chat ID: ${WHITE}$TG_CHAT_ID${NC}"
