#!/bin/bash

#==========================
# MARZBAN DATABASE MANAGER
#==========================

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

# Default paths
readonly MARZBAN_DIR="/opt/marzban"
readonly BACKUP_DIR="/opt/marzban-backups"
readonly ENV_FILE="$MARZBAN_DIR/.env"

#======================
# VALIDATION FUNCTIONS
#======================

# Check if file exists
check_file_exists() {
    local file=$1
    if [ ! -f "$file" ]; then
        return 1
    fi
    return 0
}

# Check if directory exists
check_directory_exists() {
    local dir=$1
    if [ ! -d "$dir" ]; then
        return 1
    fi
    return 0
}

# Command execution check
check_command() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}${CROSS}${NC} Error: $1"
        exit 1
    fi
}

# Check root permissions
check_root_permissions() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}${CROSS}${NC} This command must be run as root."
        exit 1
    fi
}

#=====================
# MAIN MENU FUNCTIONS
#=====================

# Display main menu
show_main_menu() {
    echo
    echo -e "${PURPLE}=========================${NC}"
    echo -e "${WHITE}MARZBAN DATABASE MANAGER${NC}"
    echo -e "${PURPLE}=========================${NC}"
    echo
    echo -e "${CYAN}Please select operation:${NC}"
    echo
    echo -e "${GREEN}1.${NC} Export Database"
    echo -e "${GREEN}2.${NC} Import Database"
    echo -e "${RED}3.${NC} Exit"
    echo
    echo -ne "${CYAN}Enter your choice (1-3): ${NC}"
}

# Handle user choice
handle_user_choice() {
    local choice=$1
    
    case $choice in
        1)
            export_database
            ;;
        2)
            import_database
            ;;
        3)
            echo
            echo -e "${YELLOW}${WARNING}${NC} Exiting database manager..."
            exit 0
            ;;
        *)
            echo
            echo -e "${RED}${CROSS}${NC} Invalid choice. Please select 1-3."
            exit 1
            ;;
    esac
}

#=====================
# DETECTION FUNCTIONS
#=====================

# Parse MySQL credentials
parse_mysql_credentials() {
    echo -e "${CYAN}${INFO}${NC} Reading database configuration..."
    
    if ! check_file_exists "$ENV_FILE"; then
        echo -e "${RED}${CROSS}${NC} Marzban .env file not found at: $ENV_FILE"
        echo -e "${YELLOW}${WARNING}${NC} Please ensure Marzban is installed in: $MARZBAN_DIR"
        exit 1
    fi

    local db_url=$(grep "^SQLALCHEMY_DATABASE_URL" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- | tr -d ' "')
    
    if [[ ! "$db_url" == *"mysql"* ]] && [[ ! "$db_url" == *"mariadb"* ]]; then
        echo -e "${RED}${CROSS}${NC} MariaDB/MySQL database not found in configuration"
        exit 1
    fi
    
    # Extract credentials from URL like: mysql+pymysql://user:pass@host:port/db
    DB_USER=$(echo "$db_url" | sed -n 's|.*://\([^:]*\):.*|\1|p')
    DB_PASS=$(echo "$db_url" | sed -n 's|.*://[^:]*:\([^@]*\)@.*|\1|p')
    DB_HOST=$(echo "$db_url" | sed -n 's|.*@\([^:]*\):.*|\1|p')
    DB_PORT=$(echo "$db_url" | sed -n 's|.*:\([0-9]*\)/.*|\1|p')
    DB_NAME=$(echo "$db_url" | sed -n 's|.*/\([^?]*\).*|\1|p')
    
    # Set defaults if not found
    DB_HOST=${DB_HOST:-"127.0.0.1"}
    DB_PORT=${DB_PORT:-"3306"}
    
    echo -e "${GRAY}  ${ARROW}${NC} Database: $DB_NAME"
    echo -e "${GRAY}  ${ARROW}${NC} Host: $DB_HOST:$DB_PORT"
    echo -e "${GRAY}  ${ARROW}${NC} User: $DB_USER"
    echo -e "${GREEN}${CHECK}${NC} Database configuration loaded!"
    echo
}

# Setup Docker Compose command
setup_docker_compose() {
    if docker compose version >/dev/null 2>&1; then
        COMPOSE='docker compose'
    elif docker-compose version >/dev/null 2>&1; then
        COMPOSE='docker-compose'
    else
        echo -e "${RED}${CROSS}${NC} Docker Compose not found."
        exit 1
    fi
}

#========================
# BACKUP DIRECTORY SETUP
#========================

# Create backup directory
create_backup_directory() {
    echo -e "${CYAN}${INFO}${NC} Setting up backup directory..."
    echo -e "${GRAY}  ${ARROW}${NC} Creating backup directory: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    check_command "Failed to create backup directory"
    
    echo -e "${GRAY}  ${ARROW}${NC} Setting directory permissions"
    chmod 700 "$BACKUP_DIR"
    echo -e "${GREEN}${CHECK}${NC} Backup directory ready!"
    echo
}

#==================
# EXPORT FUNCTIONS
#==================

# Export database
export_database() {
    echo
    echo -e "${PURPLE}================${NC}"
    echo -e "${WHITE}Database Export${NC}"
    echo -e "${PURPLE}================${NC}"
    echo
    
    check_root_permissions
    parse_mysql_credentials
    setup_docker_compose
    create_backup_directory
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$BACKUP_DIR/marzban_backup_${timestamp}"
    
    # We need to pass user_count to display function
    export_mysql_database "$backup_file"
    display_export_success "$backup_file"
}

# Export MySQL database
export_mysql_database() {
    local backup_file=$1
    
    echo -e "${CYAN}${INFO}${NC} Exporting MariaDB database..."
    
    echo -e "${GRAY}  ${ARROW}${NC} Finding database container"
    
    # Look for specific MariaDB container name
    local container_id=$(docker ps -q -f name=marzban-mariadb-1 -f status=running)
    
    if [ -z "$container_id" ]; then
        echo -e "${RED}${CROSS}${NC} MariaDB container 'marzban-mariadb-1' not found or not running"
        echo -e "${YELLOW}${WARNING}${NC} Available containers:"
        docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
        exit 1
    fi
    
    echo -e "${GRAY}  ${ARROW}${NC} Using container: marzban-mariadb-1"
    
    echo -e "${GRAY}  ${ARROW}${NC} Testing database connection"
    if ! docker exec "$container_id" mariadb -u "$DB_USER" -p"$DB_PASS" -e "SELECT 1;" >/dev/null 2>&1; then
        echo -e "${RED}${CROSS}${NC} Failed to connect to database"
        echo -e "${YELLOW}${WARNING}${NC} Debugging connection issue..."
        echo -e "${GRAY}  Database: $DB_NAME${NC}"
        echo -e "${GRAY}  User: $DB_USER${NC}"
        echo -e "${GRAY}  Host: $DB_HOST:$DB_PORT${NC}"
        echo
        echo -e "${YELLOW}${INFO}${NC} Testing container health:"
        docker exec "$container_id" healthcheck.sh --connect --innodb_initialized 2>/dev/null || echo "Health check failed"
        echo
        echo -e "${YELLOW}${INFO}${NC} Testing basic MariaDB connection:"
        docker exec "$container_id" mariadb -u root -p"$(grep "^MYSQL_ROOT_PASSWORD=" "$ENV_FILE" | cut -d'=' -f2)" -e "SHOW DATABASES;" 2>/dev/null || echo "Root connection failed"
        echo
        echo -e "${YELLOW}${INFO}${NC} Checking if user exists:"
        docker exec "$container_id" mariadb -u root -p"$(grep "^MYSQL_ROOT_PASSWORD=" "$ENV_FILE" | cut -d'=' -f2)" -e "SELECT User FROM mysql.user WHERE User='$DB_USER';" 2>/dev/null || echo "Cannot check users"
        echo
        echo -e "${YELLOW}${INFO}${NC} Testing connection with explicit host:"
        docker exec "$container_id" mariadb -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -e "SELECT 1;" 2>&1 | head -3
        exit 1
    fi
    
    echo -e "${GRAY}  ${ARROW}${NC} Creating MariaDB dump"
    if docker exec "$container_id" mariadb-dump -u "$DB_USER" -p"$DB_PASS" --single-transaction --routines --triggers "$DB_NAME" > "/tmp/marzban.sql" 2>/dev/null; then
        echo -e "${GREEN}${CHECK}${NC} MariaDB database exported successfully!"
    else
        echo -e "${RED}${CROSS}${NC} Failed to create database dump"
        echo -e "${YELLOW}${WARNING}${NC} Checking error details..."
        docker exec "$container_id" mariadb-dump -u "$DB_USER" -p"$DB_PASS" --single-transaction --routines --triggers "$DB_NAME" 2>&1 | head -5
        exit 1
    fi
    
    local user_count=$(docker exec "$container_id" mariadb -u "$DB_USER" -p"$DB_PASS" -D "$DB_NAME" -e "SELECT COUNT(*) FROM users;" 2>/dev/null | tail -1 | tr -d ' ')
    if [[ ! "$user_count" =~ ^[0-9]+$ ]]; then
        user_count="unknown"
    fi
    
    local date_formatted=$(date +"%d-%m-%Y_%H-%M")
    local archive_name="mb_${date_formatted}_${user_count}-users.tar.gz"
    
    cd /tmp
    tar -czf "$BACKUP_DIR/$archive_name" marzban.sql > /dev/null 2>&1
    check_command "Failed to create archive"
    
    rm -f /tmp/marzban.sql
    
    # Store archive name for display function
    backup_file="$BACKUP_DIR/${archive_name%.*}"
    USER_COUNT_EXPORTED="$user_count"
    ARCHIVE_NAME="$archive_name"
}

#==================
# IMPORT FUNCTIONS
#==================

# Import database
import_database() {
    echo
    echo -e "${PURPLE}================${NC}"
    echo -e "${WHITE}Database Import${NC}"
    echo -e "${PURPLE}================${NC}"
    echo
    
    check_root_permissions
    parse_mysql_credentials
    setup_docker_compose
    
    select_backup_file
    confirm_import_operation
    import_mysql_database
    display_import_success
}

# Select backup file
select_backup_file() {
    echo -e "${CYAN}Available backups:${NC}"
    echo
    
    if ! check_directory_exists "$BACKUP_DIR"; then
        echo -e "${RED}${CROSS}${NC} No backup directory found at: $BACKUP_DIR"
        exit 1
    fi
    
    local backups=($(find "$BACKUP_DIR" -name "mb_*.tar.gz" -type f | sort -r))
    
    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${RED}${CROSS}${NC} No backups found in: $BACKUP_DIR"
        exit 1
    fi
    
    local i=1
    for backup_file in "${backups[@]}"; do
        local backup_name=$(basename "$backup_file")
        local backup_date=$(date -r "$backup_file" "+%d-%m-%Y" 2>/dev/null || echo "Unknown")
        
        # Extract user count from filename
        local user_info=$(echo "$backup_name" | sed -n 's/.*_\([^_]*-users\)\.tar\.gz/\1/p')
        
        echo -e "${GREEN}$i.${NC} $backup_name"
        echo -e "${GRAY}   Date: $backup_date${NC}"
        echo -e "${GRAY}   Users: $user_info${NC}"
        echo
        i=$((i + 1))
    done
    
    echo -ne "${CYAN}Select backup to restore (1-${#backups[@]}): ${NC}"
    read selection
    
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#backups[@]} ]; then
        echo -e "${RED}${CROSS}${NC} Invalid selection"
        exit 1
    fi
    
    SELECTED_BACKUP_FILE="${backups[$((selection-1))]}"
    
    echo -e "${GRAY}  ${ARROW}${NC} Extracting backup archive"
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    tar -xzf "$SELECTED_BACKUP_FILE" > /dev/null 2>&1
    check_command "Failed to extract backup archive"
    
    if [ ! -f "$temp_dir/marzban.sql" ]; then
        echo -e "${RED}${CROSS}${NC} marzban.sql not found in archive"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    EXTRACTED_SQL_FILE="$temp_dir/marzban.sql"
}

# Confirm import operation
confirm_import_operation() {
    echo
    echo -e "${YELLOW}${WARNING}${NC} ${RED}WARNING: This operation will REPLACE your current database!${NC}"
    echo
    echo -e "${CYAN}Selected backup:${NC} $(basename "$SELECTED_BACKUP_FILE")"
    echo
    echo -ne "${YELLOW}Continue with database replacement? (y/N): ${NC}"
    read -r CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo
        echo -e "${CYAN}Import cancelled.${NC}"
        exit 0
    fi
    
    echo
    echo -e "${CYAN}${INFO}${NC} Creating safety backup of current database..."
    local safety_backup="$BACKUP_DIR/safety_backup_$(date +%Y%m%d_%H%M%S)"
    
    # Look for specific MariaDB container name
    local container_id=$(docker ps -q -f name=marzban-mariadb-1 -f status=running)
    
    if [ -n "$container_id" ]; then
        echo -e "${GRAY}  ${ARROW}${NC} Creating safety backup"
        docker exec "$container_id" mariadb-dump -u "$DB_USER" -p"$DB_PASS" --single-transaction --routines --triggers "$DB_NAME" > "/tmp/safety_marzban.sql" 2>/dev/null
        if [ -f "/tmp/safety_marzban.sql" ]; then
            local safety_date=$(date +"%d-%m-%Y_%H-%M")
            tar -czf "${safety_backup}_${safety_date}.tar.gz" -C /tmp safety_marzban.sql > /dev/null 2>&1
            rm -f /tmp/safety_marzban.sql
        fi
    fi
    echo -e "${GREEN}${CHECK}${NC} Safety backup created (if possible)"
    echo
}

# Import MySQL database
import_mysql_database() {
    echo -e "${CYAN}${INFO}${NC} Importing MariaDB database..."
    
    local backup_file="$EXTRACTED_SQL_FILE"
    if ! check_file_exists "$backup_file"; then
        echo -e "${RED}${CROSS}${NC} Backup file not found: $backup_file"
        exit 1
    fi
    
    echo -e "${GRAY}  ${ARROW}${NC} Finding database container"
    
    # Look for specific MariaDB container name
    local container_id=$(docker ps -q -f name=marzban-mariadb-1 -f status=running)
    
    if [ -z "$container_id" ]; then
        echo -e "${RED}${CROSS}${NC} MariaDB container 'marzban-mariadb-1' not found or not running"
        echo -e "${YELLOW}${WARNING}${NC} Available containers:"
        docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
        exit 1
    fi
    
    echo -e "${GRAY}  ${ARROW}${NC} Using container: marzban-mariadb-1"
    
    echo -e "${GRAY}  ${ARROW}${NC} Testing database connection"
    if ! docker exec "$container_id" mariadb -u "$DB_USER" -p"$DB_PASS" -e "SELECT 1;" >/dev/null 2>&1; then
        echo -e "${RED}${CROSS}${NC} Failed to connect to database"
        echo -e "${YELLOW}${WARNING}${NC} Please check database credentials in $ENV_FILE"
        exit 1
    fi
    
    echo -e "${GRAY}  ${ARROW}${NC} Stopping Marzban container"
    cd "$MARZBAN_DIR"
    $COMPOSE stop marzban > /dev/null 2>&1
    
    echo -e "${GRAY}  ${ARROW}${NC} Dropping existing database"
    docker exec "$container_id" mariadb -u "$DB_USER" -p"$DB_PASS" -e "DROP DATABASE IF EXISTS $DB_NAME;" 2>/dev/null
    
    echo -e "${GRAY}  ${ARROW}${NC} Creating new database"
    docker exec "$container_id" mariadb -u "$DB_USER" -p"$DB_PASS" -e "CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null
    check_command "Failed to create database"
    
    echo -e "${GRAY}  ${ARROW}${NC} Importing database from backup"
    if docker exec -i "$container_id" mariadb -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$EXTRACTED_SQL_FILE" 2>/dev/null; then
        echo -e "${GREEN}${CHECK}${NC} Database import completed successfully!"
    else
        echo -e "${RED}${CROSS}${NC} Failed to import database"
        echo -e "${YELLOW}${WARNING}${NC} Checking error details..."
        docker exec -i "$container_id" mariadb -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$EXTRACTED_SQL_FILE" 2>&1 | head -5
        rm -rf "$temp_dir"
        exit 1
    fi
    
    echo
    echo -e "${CYAN}${INFO}${NC} Finalizing import process..."
    echo -e "${GRAY}  ${ARROW}${NC} Cleaning up temporary files"
    rm -rf "$temp_dir"
    
    echo -e "${GRAY}  ${ARROW}${NC} Starting Marzban container"
    $COMPOSE start marzban > /dev/null 2>&1
    
    echo -e "${GREEN}${CHECK}${NC} MariaDB database imported successfully!"
}

#===========================
# SUCCESS DISPLAY FUNCTIONS
#===========================

# Display export success
display_export_success() {
    local backup_file=$1
    
    echo
    echo -e "${PURPLE}===================${NC}"
    echo -e "${GREEN}${CHECK}${NC} Export Complete!"
    echo -e "${PURPLE}===================${NC}"
    echo
    echo -e "${CYAN}Backup Location:${NC}"
    echo -e "${WHITE}$BACKUP_DIR/$ARCHIVE_NAME${NC}"
    echo
    echo -e "${CYAN}Users Exported:${NC} $USER_COUNT_EXPORTED"
    echo
}

# Display import success
display_import_success() {
    echo
    echo -e "${PURPLE}===================${NC}"
    echo -e "${GREEN}${CHECK}${NC} Import Complete!"
    echo -e "${PURPLE}===================${NC}"
    echo
    echo -e "${CYAN}Database Restored:${NC} $(basename "$SELECTED_BACKUP_FILE")"
    echo
}

#==================
# MAIN ENTRY POINT
#==================

# Main function
main() {
    # Check if Docker is installed
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}${CROSS}${NC} Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    show_main_menu
    read OPERATION_TYPE
    handle_user_choice "$OPERATION_TYPE"
}

#==================
# SCRIPT EXECUTION
#==================

# Run main function
main
