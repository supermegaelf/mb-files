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
SHOP_MYSQL_USER=""
SHOP_MYSQL_PASSWORD=""
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

    # Always request configuration if any variable is empty
    if [ -z "$MYSQL_USER" ] || [ -z "$MYSQL_PASSWORD" ] || [ -z "$SHOP_MYSQL_USER" ] || [ -z "$SHOP_MYSQL_PASSWORD" ] || [ -z "$TG_BOT_TOKEN" ] || [ -z "$TG_CHAT_ID" ]; then
        
        # Marzban database credentials
        echo -ne "${CYAN}Marzban MySQL username (default is marzban, press Enter to use default): ${NC}"
        read MYSQL_USER
        MYSQL_USER=${MYSQL_USER:-marzban}
        
        echo -ne "${CYAN}Marzban MySQL password: ${NC}"
        read MYSQL_PASSWORD
        echo

        # Shop/Bot database credentials
        echo -ne "${CYAN}Shop/Bot MySQL username (default is marzban, press Enter to use default): ${NC}"
        read SHOP_MYSQL_USER
        SHOP_MYSQL_USER=${SHOP_MYSQL_USER:-marzban}
        
        echo -ne "${CYAN}Shop/Bot MySQL password: ${NC}"
        read SHOP_MYSQL_PASSWORD
        echo

        # Telegram configuration
        echo -ne "${CYAN}Telegram Bot Token: ${NC}"
        read TG_BOT_TOKEN
        
        echo -ne "${CYAN}Telegram Chat ID: ${NC}"
        read TG_CHAT_ID
        echo

        # Validation
        if [ -z "$MYSQL_USER" ]; then
            echo -e "${RED}${CROSS}${NC} Marzban MySQL username cannot be empty"
            exit 1
        fi
        if [ -z "$MYSQL_PASSWORD" ]; then
            echo -e "${RED}${CROSS}${NC} Marzban MySQL password cannot be empty"
            exit 1
        fi
        if [ -z "$SHOP_MYSQL_USER" ]; then
            echo -e "${RED}${CROSS}${NC} Shop MySQL username cannot be empty"
            exit 1
        fi
        if [ -z "$SHOP_MYSQL_PASSWORD" ]; then
            echo -e "${RED}${CROSS}${NC} Shop MySQL password cannot be empty"
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

        sed -i "s|MYSQL_USER=\"[^\"]*\"|MYSQL_USER=\"$MYSQL_USER\"|" "$0"
        sed -i "s|MYSQL_PASSWORD=\"[^\"]*\"|MYSQL_PASSWORD=\"$MYSQL_PASSWORD\"|" "$0"
        sed -i "s|SHOP_MYSQL_USER=\"[^\"]*\"|SHOP_MYSQL_USER=\"$SHOP_MYSQL_USER\"|" "$0"
        sed -i "s|SHOP_MYSQL_PASSWORD=\"[^\"]*\"|SHOP_MYSQL_PASSWORD=\"$SHOP_MYSQL_PASSWORD\"|" "$0"
        sed -i "s|TG_BOT_TOKEN=\"[^\"]*\"|TG_BOT_TOKEN=\"$TG_BOT_TOKEN\"|" "$0"
        sed -i "s|TG_CHAT_ID=\"[^\"]*\"|TG_CHAT_ID=\"$TG_CHAT_ID\"|" "$0"

        if ! grep -q "/root/scripts/mb-backup.sh" /etc/crontab; then
            echo "0 */1 * * * root /bin/bash /root/scripts/mb-backup.sh >/dev/null 2>&1" | tee -a /etc/crontab > /dev/null 2>&1
        fi
        
        echo -e "${GREEN}${CHECK}${NC} Configuration saved successfully!"
        echo
    fi
}

#======================
# VALIDATION FUNCTIONS
#======================

validate_configuration() {
    if [ -z "$MYSQL_USER" ]; then
        echo -e "${RED}${CROSS}${NC} Marzban MySQL username cannot be empty"
        exit 1
    fi

    if [ -z "$MYSQL_PASSWORD" ]; then
        echo -e "${RED}${CROSS}${NC} Marzban MySQL password cannot be empty"
        exit 1
    fi

    if [ -z "$SHOP_MYSQL_USER" ]; then
        echo -e "${RED}${CROSS}${NC} Shop MySQL username cannot be empty"
        exit 1
    fi

    if [ -z "$SHOP_MYSQL_PASSWORD" ]; then
        echo -e "${RED}${CROSS}${NC} Shop MySQL password cannot be empty"
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
    echo -e "${GRAY}  ${ARROW}${NC} Checking Shop database containers"
    echo -e "${GRAY}  ${ARROW}${NC} Validating container health"

    MYSQL_CONTAINER_NAME="marzban-mariadb-1"
    if ! docker ps -q -f name="$MYSQL_CONTAINER_NAME" | grep -q .; then
        echo -e "${RED}${CROSS}${NC} Container $MYSQL_CONTAINER_NAME is not running"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # Check for both possible shop database containers
    SHOP_CONTAINER_NAME=""
    
    if docker ps -q -f name="marzban-shop-db-1" | grep -q .; then
        SHOP_CONTAINER_NAME="marzban-shop-db-1"
        echo -e "${GRAY}  ${ARROW}${NC} Marzban shop database container detected"
    elif docker ps -q -f name="shop-bot-db-1" | grep -q .; then
        SHOP_CONTAINER_NAME="shop-bot-db-1"
        echo -e "${GRAY}  ${ARROW}${NC} Shop bot database container detected"
    else
        echo -e "${GRAY}  ${ARROW}${NC} No shop database container found"
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
    echo -e "${GRAY}  ${ARROW}${NC} Setting up backup directory"
    echo -e "${GRAY}  ${ARROW}${NC} Exporting database content"

    mkdir -p /var/lib/marzban/mysql/db-backup/ > /dev/null 2>&1

    # Backup marzban database from main container
    databases_marzban=$(docker exec $MYSQL_CONTAINER_NAME mariadb -h 127.0.0.1 --user="$MYSQL_USER" --password="$MYSQL_PASSWORD" -e "SHOW DATABASES;" 2>/dev/null | tr -d "| " | grep -v Database)
    if [ $? -ne 0 ]; then
        echo -e "${GRAY}  ${ARROW}${NC} Failed to retrieve Marzban databases"
        echo -e "${RED}${CROSS}${NC} Database backup failed"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    MARZBAN_DUMPED=false
    for db in $databases_marzban; do
        if [[ "$db" == "marzban" ]]; then
            docker exec $MYSQL_CONTAINER_NAME mariadb-dump -h 127.0.0.1 --force --opt --user="$MYSQL_USER" --password="$MYSQL_PASSWORD" --databases $db > /var/lib/marzban/mysql/db-backup/$db.sql 2>/dev/null
            if [ $? -eq 0 ]; then
                MARZBAN_DUMPED=true
                echo -e "${GRAY}  ${ARROW}${NC} Marzban database backed up"
            else
                echo -e "${GRAY}  ${ARROW}${NC} Failed to backup marzban database"
            fi
        fi
    done

    # Backup shop database from shop container if exists
    SHOP_DUMPED=false
    if [ -n "$SHOP_CONTAINER_NAME" ]; then
        databases_shop=$(docker exec $SHOP_CONTAINER_NAME mariadb -h 127.0.0.1 --user="$SHOP_MYSQL_USER" --password="$SHOP_MYSQL_PASSWORD" -e "SHOW DATABASES;" 2>/dev/null | tr -d "| " | grep -v Database)
        if [ $? -eq 0 ]; then
            for db in $databases_shop; do
                if [[ "$db" == "shop" ]]; then
                    docker exec $SHOP_CONTAINER_NAME mariadb-dump -h 127.0.0.1 --force --opt --user="$SHOP_MYSQL_USER" --password="$SHOP_MYSQL_PASSWORD" --databases $db > /var/lib/marzban/mysql/db-backup/$db.sql 2>/dev/null
                    if [ $? -eq 0 ]; then
                        SHOP_DUMPED=true
                        echo -e "${GRAY}  ${ARROW}${NC} Shop database backed up"
                    else
                        echo -e "${GRAY}  ${ARROW}${NC} Failed to backup shop database"
                    fi
                fi
            done
        else
            echo -e "${GRAY}  ${ARROW}${NC} Could not access shop database"
        fi
    else
        echo -e "${GRAY}  ${ARROW}${NC} Skipping shop database (no container)"
    fi

    echo -e "${GREEN}${CHECK}${NC} Database backup creation completed!"
}

create_archive() {
    echo
    echo -e "${GREEN}Archive Creation${NC}"
    echo -e "${GREEN}================${NC}"
    echo

    echo -e "${CYAN}${INFO}${NC} Building backup archive..."
    echo -e "${GRAY}  ${ARROW}${NC} Collecting configuration files"
    echo -e "${GRAY}  ${ARROW}${NC} Adding database backups"
    echo -e "${GRAY}  ${ARROW}${NC} Finalizing archive structure"

    # Create a list of files to backup
    FILES_TO_BACKUP=""

    # Required files (must exist)
    REQUIRED_FILES=(
        "/opt/marzban/.env"
        "/opt/marzban/docker-compose.yml"
        "/var/lib/marzban/mysql/db-backup/marzban.sql"
        "/var/lib/marzban/templates"
        "/var/lib/marzban/xray_config.json"
    )

    # Optional files (include if they exist)
    OPTIONAL_FILES=(
        "/var/lib/marzban/mysql/db-backup/shop.sql"
        "/root/shop-bot/.env"
        "/root/shop-bot/goods.json"
        "/root/marzban-shop/.env"
        "/root/marzban-shop/goods.json"
    )

    # Check required files
    for file in "${REQUIRED_FILES[@]}"; do
        if [ -e "$file" ]; then
            FILES_TO_BACKUP="$FILES_TO_BACKUP $file"
        else
            echo -e "${GRAY}  ${ARROW}${NC} Required file not found: $file"
        fi
    done

    # Check optional files
    for file in "${OPTIONAL_FILES[@]}"; do
        if [ -e "$file" ]; then
            FILES_TO_BACKUP="$FILES_TO_BACKUP $file"
            echo -e "${GRAY}  ${ARROW}${NC} Including optional: $(basename $file)"
        fi
    done

    # Create the tar archive with the collected files
    if [ -n "$FILES_TO_BACKUP" ]; then
        tar -czf "$BACKUP_FILE" -C / $FILES_TO_BACKUP > /dev/null 2>&1
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}${CHECK}${NC} Backup archive created successfully!"
        else
            echo -e "${RED}${CROSS}${NC} Failed to create backup archive"
            rm -rf "$TEMP_DIR"
            exit 1
        fi
    else
        echo -e "${RED}${CROSS}${NC} No files found to backup"
        rm -rf "$TEMP_DIR"
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
