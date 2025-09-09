#!/bin/bash

#=========================
# MARZBAN TELEGRAM BACKUP
#=========================

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
MYSQL_USER=""
MYSQL_PASSWORD=""
SHOP_BOT_MYSQL_USER=""
SHOP_BOT_MYSQL_PASSWORD=""
TG_BOT_TOKEN=""
TG_CHAT_ID=""

#=====================
# CONFIGURATION SETUP
#=====================

configure_backup() {
    echo
    echo -e "${PURPLE}========================${NC}"
    echo -e "${NC}MARZBAN TELEGRAM BACKUP${NC}"
    echo -e "${PURPLE}========================${NC}"
    echo

    if [ -z "$MYSQL_USER" ] || [ -z "$MYSQL_PASSWORD" ] || [ -z "$TG_BOT_TOKEN" ] || [ -z "$TG_CHAT_ID" ]; then
        echo -ne "${CYAN}Marzban MySQL username (default is marzban, press Enter to use it): ${NC}"
        read MYSQL_USER
        MYSQL_USER=${MYSQL_USER:-marzban}
        echo -ne "${CYAN}Marzban MySQL password: ${NC}"
        read MYSQL_PASSWORD

        echo -ne "${CYAN}Bot MySQL username (default is marzban, press Enter to use it): ${NC}"
        read SHOP_BOT_MYSQL_USER
        SHOP_BOT_MYSQL_USER=${SHOP_BOT_MYSQL_USER:-marzban}
        echo -ne "${CYAN}Bot MySQL password: ${NC}"
        read SHOP_BOT_MYSQL_PASSWORD

        echo -ne "${CYAN}Telegram Bot Token: ${NC}"
        read TG_BOT_TOKEN
        echo -ne "${CYAN}Telegram Chat ID: ${NC}"
        read TG_CHAT_ID
        echo

        if [ -z "$MYSQL_USER" ]; then
            echo -e "${RED}${CROSS}${NC} Marzban MySQL username cannot be empty"
            exit 1
        fi
        if [ -z "$MYSQL_PASSWORD" ]; then
            echo -e "${RED}${CROSS}${NC} Marzban MySQL password cannot be empty"
            exit 1
        fi
        if [ -z "$SHOP_BOT_MYSQL_PASSWORD" ]; then
            echo -e "${RED}${CROSS}${NC} Bot MySQL password cannot be empty"
            exit 1
        fi
        if [[ ! "$TG_BOT_TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
            echo -e "${RED}${CROSS}${NC} Invalid Telegram Bot Token format"
            exit 1
        fi
        if [[ ! "$TG_CHAT_ID" =~ ^-?[0-9]+$ ]]; then
            echo -e "${RED}${CROSS}${NC} Invalid Telegram Chat ID format"
            exit 1
        fi

        echo -e "${CYAN}${INFO}${NC} Saving configuration..."
        echo -e "${GRAY}  ${ARROW}${NC} Updating MySQL credentials"
        echo -e "${GRAY}  ${ARROW}${NC} Setting Telegram parameters"
        echo -e "${GRAY}  ${ARROW}${NC} Creating cron schedule"

        sed -i "s/MYSQL_USER=\"\"/MYSQL_USER=\"$MYSQL_USER\"/" "$0"
        sed -i "s/MYSQL_PASSWORD=\"\"/MYSQL_PASSWORD=\"$MYSQL_PASSWORD\"/" "$0"
        sed -i "s/SHOP_BOT_MYSQL_USER=\"\"/SHOP_BOT_MYSQL_USER=\"$SHOP_BOT_MYSQL_USER\"/" "$0"
        sed -i "s/SHOP_BOT_MYSQL_PASSWORD=\"\"/SHOP_BOT_MYSQL_PASSWORD=\"$SHOP_BOT_MYSQL_PASSWORD\"/" "$0"
        sed -i "s/TG_BOT_TOKEN=\"\"/TG_BOT_TOKEN=\"$TG_BOT_TOKEN\"/" "$0"
        sed -i "s/TG_CHAT_ID=\"\"/TG_CHAT_ID=\"$TG_CHAT_ID\"/" "$0"

        if ! grep -q "mb-backup.sh" /etc/crontab; then
            echo "0 */1 * * * root /bin/bash /root/scripts/mb-backup.sh >/dev/null 2>&1" | tee -a /etc/crontab > /dev/null 2>&1
        fi
        
        echo -e "${GREEN}${CHECK}${NC} Configuration saved successfully!"
        echo
        return 0
    fi
}

#======================
# VALIDATION FUNCTIONS
#======================

validate_configuration() {
    if [ -z "$MYSQL_USER" ]; then
        echo -e "${RED}${CROSS}${NC} MySQL username cannot be empty"
        exit 1
    fi

    if [ -z "$MYSQL_PASSWORD" ]; then
        echo -e "${RED}${CROSS}${NC} MySQL password cannot be empty"
        exit 1
    fi

    if [[ ! "$TG_BOT_TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
        echo -e "${RED}${CROSS}${NC} Invalid Telegram Bot Token format"
        exit 1
    fi

    if [[ ! "$TG_CHAT_ID" =~ ^-?[0-9]+$ ]]; then
        echo -e "${RED}${CROSS}${NC} Invalid Telegram Chat ID format"
        exit 1
    fi
}

#================
# MAIN FUNCTIONS
#================

prepare_system() {
    echo -e "${GREEN}System Preparation${NC}"
    echo -e "${GREEN}==================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Setting up backup environment..."
    echo -e "${GRAY}  ${ARROW}${NC} Creating temporary directory"
    echo -e "${GRAY}  ${ARROW}${NC} Initializing backup variables"
    echo -e "${GRAY}  ${ARROW}${NC} Validating permissions"

    TEMP_DIR=$(mktemp -d)
    if [ ! -d "$TEMP_DIR" ]; then
        echo -e "${RED}${CROSS}${NC} Failed to create temporary directory"
        exit 1
    fi
    BACKUP_FILE="$TEMP_DIR/backup-marzban.tar.gz"

    echo -e "${GREEN}${CHECK}${NC} System preparation completed!"
}

check_containers() {
    echo
    echo -e "${GREEN}Docker Container Check${NC}"
    echo -e "${GREEN}======================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Checking Docker containers status..."
    echo -e "${GRAY}  ${ARROW}${NC} Verifying Marzban MariaDB container"
    echo -e "${GRAY}  ${ARROW}${NC} Checking for Shop bot containers"
    echo -e "${GRAY}  ${ARROW}${NC} Validating container health"

    MYSQL_CONTAINER_NAME="marzban-mariadb-1"
    if ! docker ps -q -f name="$MYSQL_CONTAINER_NAME" | grep -q .; then
        echo -e "${RED}${CROSS}${NC} Container $MYSQL_CONTAINER_NAME is not running"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # Check for shop containers (either marzban-shop or shop-bot)
    SHOP_CONTAINER_NAME=""
    SHOP_TYPE=""
    
    if docker ps -q -f name="marzban-shop-db-1" | grep -q .; then
        SHOP_CONTAINER_NAME="marzban-shop-db-1"
        SHOP_TYPE="marzban-shop"
        echo -e "${CYAN}${INFO}${NC} Marzban-shop container detected and running"
    elif docker ps -q -f name="shop-bot-db-1" | grep -q .; then
        SHOP_CONTAINER_NAME="shop-bot-db-1"
        SHOP_TYPE="shop-bot"
        echo -e "${CYAN}${INFO}${NC} Shop-bot container detected and running"
    else
        echo -e "${YELLOW}${WARNING}${NC} No shop containers found, skipping shop database"
    fi

    echo -e "${GREEN}${CHECK}${NC} Docker containers validated!"
}

create_database_backup() {
    echo
    echo -e "${GREEN}Database Backup Creation${NC}"
    echo -e "${GREEN}========================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Creating database backups..."
    echo -e "${GRAY}  ${ARROW}${NC} Retrieving Marzban databases"
    if [ -n "$SHOP_CONTAINER_NAME" ]; then
        echo -e "${GRAY}  ${ARROW}${NC} Retrieving Shop databases ($SHOP_TYPE)"
    fi
    echo -e "${GRAY}  ${ARROW}${NC} Setting up backup directory"
    echo -e "${GRAY}  ${ARROW}${NC} Exporting database content"

    # Backup Marzban database
    databases_marzban=$(docker exec $MYSQL_CONTAINER_NAME mariadb -h 127.0.0.1 --user="$MYSQL_USER" --password="$MYSQL_PASSWORD" -e "SHOW DATABASES;" 2>/tmp/marzban_error.log | tr -d "| " | grep -v Database)
    if [ $? -ne 0 ]; then
        echo -e "${RED}${CROSS}${NC} Failed to retrieve marzban databases"
        cat /tmp/marzban_error.log
        rm -rf "$TEMP_DIR" /tmp/marzban_error.log
        exit 1
    fi
    rm -f /tmp/marzban_error.log

    # Backup Shop database (if any shop container exists)
    databases_shop=""
    if [ -n "$SHOP_CONTAINER_NAME" ]; then
        # Use different credentials for shop-bot
        if [ "$SHOP_TYPE" = "shop-bot" ]; then
            databases_shop=$(docker exec $SHOP_CONTAINER_NAME mariadb -h 127.0.0.1 --user="$SHOP_BOT_MYSQL_USER" --password="$SHOP_BOT_MYSQL_PASSWORD" -e "SHOW DATABASES;" 2>/tmp/shop_error.log | tr -d "| " | grep -v Database)
        else
            databases_shop=$(docker exec $SHOP_CONTAINER_NAME mariadb -h 127.0.0.1 --user="$MYSQL_USER" --password="$MYSQL_PASSWORD" -e "SHOW DATABASES;" 2>/tmp/shop_error.log | tr -d "| " | grep -v Database)
        fi
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}${CROSS}${NC} Failed to retrieve shop databases from $SHOP_CONTAINER_NAME"
            cat /tmp/shop_error.log
            rm -rf "$TEMP_DIR" /tmp/shop_error.log
            exit 1
        fi
        rm -f /tmp/shop_error.log
    fi

    mkdir -p /var/lib/marzban/mysql/db-backup/ > /dev/null 2>&1

    # Export Marzban database
    for db in $databases_marzban; do
        if [[ "$db" == "marzban" ]]; then
            docker exec $MYSQL_CONTAINER_NAME mariadb-dump -h 127.0.0.1 --force --opt --user="$MYSQL_USER" --password="$MYSQL_PASSWORD" --databases $db > /var/lib/marzban/mysql/db-backup/$db.sql
            echo -e "${GRAY}    ✓ Exported marzban database${NC}"
        fi
    done

    # Export Shop database (from whichever container is running)
    if [ -n "$databases_shop" ]; then
        for db in $databases_shop; do
            if [[ "$db" == "shop" ]]; then
                if [ "$SHOP_TYPE" = "shop-bot" ]; then
                    docker exec $SHOP_CONTAINER_NAME mariadb-dump -h 127.0.0.1 --force --opt --user="$SHOP_BOT_MYSQL_USER" --password="$SHOP_BOT_MYSQL_PASSWORD" --databases $db > /var/lib/marzban/mysql/db-backup/shop.sql
                else
                    docker exec $SHOP_CONTAINER_NAME mariadb-dump -h 127.0.0.1 --force --opt --user="$MYSQL_USER" --password="$MYSQL_PASSWORD" --databases $db > /var/lib/marzban/mysql/db-backup/shop.sql
                fi
                echo -e "${GRAY}    ✓ Exported shop database from $SHOP_TYPE${NC}"
            fi
        done
    fi

    echo -e "${GREEN}${CHECK}${NC} Database backup creation completed!"
}

create_archive() {
    echo
    echo -e "${GREEN}Archive Creation${NC}"
    echo -e "${GREEN}================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Building selective backup archive..."
    echo -e "${GRAY}  ${ARROW}${NC} Adding configuration files"
    echo -e "${GRAY}  ${ARROW}${NC} Adding database backups"
    echo -e "${GRAY}  ${ARROW}${NC} Adding templates directory"

    # Create list of files for backup
    BACKUP_ITEMS=""
    
    # Essential configuration files
    if [ -f /opt/marzban/.env ]; then
        BACKUP_ITEMS="$BACKUP_ITEMS /opt/marzban/.env"
        echo -e "${GRAY}    ✓ Marzban config found${NC}"
    else
        echo -e "${YELLOW}    ! Marzban .env not found${NC}"
    fi
    
    if [ -f /opt/marzban/docker-compose.yml ]; then
        BACKUP_ITEMS="$BACKUP_ITEMS /opt/marzban/docker-compose.yml"
        echo -e "${GRAY}    ✓ Docker compose found${NC}"
    else
        echo -e "${YELLOW}    ! Docker compose not found${NC}"
    fi
    
    # Shop configuration and data (either marzban-shop or shop-bot)
    if [ -f /root/marzban-shop/.env ]; then
        BACKUP_ITEMS="$BACKUP_ITEMS /root/marzban-shop/.env"
        echo -e "${GRAY}    ✓ Marzban-shop config found${NC}"
    elif [ -f /root/shop-bot/.env ]; then
        BACKUP_ITEMS="$BACKUP_ITEMS /root/shop-bot/.env"
        echo -e "${GRAY}    ✓ Shop-bot config found${NC}"
    else
        echo -e "${YELLOW}    ! No shop config found${NC}"
    fi
    
    if [ -f /root/marzban-shop/goods.json ]; then
        BACKUP_ITEMS="$BACKUP_ITEMS /root/marzban-shop/goods.json"
        echo -e "${GRAY}    ✓ Marzban-shop goods found${NC}"
    elif [ -f /root/shop-bot/goods.json ]; then
        BACKUP_ITEMS="$BACKUP_ITEMS /root/shop-bot/goods.json"
        echo -e "${GRAY}    ✓ Shop-bot goods found${NC}"
    else
        echo -e "${YELLOW}    ! No shop goods found${NC}"
    fi
    
    # Templates directory
    if [ -d /var/lib/marzban/templates ]; then
        BACKUP_ITEMS="$BACKUP_ITEMS /var/lib/marzban/templates"
        echo -e "${GRAY}    ✓ Templates directory found${NC}"
    else
        echo -e "${YELLOW}    ! Templates directory not found${NC}"
    fi
    
    # Database dumps (created earlier in the script)
    if [ -d /var/lib/marzban/mysql/db-backup ] && [ "$(ls -A /var/lib/marzban/mysql/db-backup 2>/dev/null)" ]; then
        BACKUP_ITEMS="$BACKUP_ITEMS /var/lib/marzban/mysql/db-backup"
        echo -e "${GRAY}    ✓ Database backups found${NC}"
    else
        echo -e "${YELLOW}    ! Database backups not found${NC}"
    fi

    # Create archive with only required files
    if [ -n "$BACKUP_ITEMS" ]; then
        tar -czf "$BACKUP_FILE" -C / $BACKUP_ITEMS > /dev/null 2>&1
        
        if [ $? -eq 0 ]; then
            BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
            echo -e "${GREEN}${CHECK}${NC} Selective backup created successfully! (Size: $BACKUP_SIZE)"
        else
            echo -e "${RED}${CROSS}${NC} Failed to create backup archive"
            exit 1
        fi
    else
        echo -e "${RED}${CROSS}${NC} No files found for backup"
        exit 1
    fi
}

send_to_telegram() {
    echo
    echo -e "${GREEN}Telegram Upload${NC}"
    echo -e "${GREEN}===============${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Sending backup to Telegram..."
    echo -e "${GRAY}  ${ARROW}${NC} Connecting to Telegram API"
    echo -e "${GRAY}  ${ARROW}${NC} Uploading backup file"
    echo -e "${GRAY}  ${ARROW}${NC} Verifying upload status"

    curl -F chat_id="$TG_CHAT_ID" \
         -F document=@"$BACKUP_FILE" \
         https://api.telegram.org/bot$TG_BOT_TOKEN/sendDocument > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}${CHECK}${NC} Backup successfully sent to Telegram"
        rm -rf /var/lib/marzban/mysql/db-backup/* > /dev/null 2>&1
    else
        echo -e "${RED}${CROSS}${NC} Failed to send backup to Telegram"
    fi
}

cleanup_files() {
    echo
    echo -e "${GREEN}Cleanup Process${NC}"
    echo -e "${GREEN}===============${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Cleaning up temporary files..."
    echo -e "${GRAY}  ${ARROW}${NC} Removing temporary directories"
    echo -e "${GRAY}  ${ARROW}${NC} Clearing backup cache"
    echo -e "${GRAY}  ${ARROW}${NC} Finalizing cleanup"

    rm -rf "$TEMP_DIR" > /dev/null 2>&1

    echo -e "${GREEN}${CHECK}${NC} Cleanup process completed!"
}

show_completion_summary() {
    echo
    echo -e "${PURPLE}===================${NC}"
    echo -e "${GREEN}${CHECK}${NC} Backup complete!"
    echo -e "${PURPLE}===================${NC}"
    echo
    echo -e "${CYAN}Backup Information:${NC}"
    echo -e "${WHITE}• Archive name: backup-marzban.tar.gz${NC}"
}

#==================
# MAIN ENTRY POINT
#==================

main() {
    configure_backup
    validate_configuration
    prepare_system
    check_containers
    create_database_backup
    create_archive
    send_to_telegram
    cleanup_files
    show_completion_summary
    echo
}

# Execute main function
main
