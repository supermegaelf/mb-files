#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

CHECK="✓"
CROSS="✗"
INFO="*"

echo
echo -e "${CYAN}================================${NC}"
echo -e "${WHITE}MARZBAN → REMNAWAVE MIGRATION${NC}"
echo -e "${CYAN}================================${NC}"
echo

if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}${CROSS}${NC} Run as root"
    exit 1
fi

echo -e "${GREEN}Select mode:${NC}"
echo "1. EXPORT (from Marzban)"
echo "2. IMPORT (to Remnawave)"
echo
echo -ne "${CYAN}Choice (1 or 2): ${NC}"
read MODE

case $MODE in
    1)
        #==================
        # EXPORT MODE
        #==================
        
        echo
        echo -e "${GREEN}=== EXPORT MODE ===${NC}"
        echo
        
        # Проверка Marzban
        if [ ! -d "/opt/marzban" ]; then
            echo -e "${RED}${CROSS}${NC} Marzban not found in /opt/marzban"
            exit 1
        fi
        
        # Поиск MariaDB контейнера
        MARZBAN_DB=$(docker ps -q -f name=mariadb)
        if [ -z "$MARZBAN_DB" ]; then
            MARZBAN_DB=$(docker ps -q -f ancestor=mariadb)
        fi
        
        if [ -z "$MARZBAN_DB" ]; then
            echo -e "${RED}${CROSS}${NC} MariaDB container not found"
            exit 1
        fi
        
        echo -e "${GREEN}${CHECK}${NC} Marzban detected"
        
        # Пароль БД
        echo -ne "${CYAN}Marzban DB password: ${NC}"
        read -s DB_PASS
        echo
        
        if [ -z "$DB_PASS" ]; then
            echo -e "${RED}${CROSS}${NC} Password cannot be empty"
            exit 1
        fi
        
        # Проверка подключения
        echo -e "${CYAN}${INFO}${NC} Testing DB connection..."
        if ! docker exec -i "$MARZBAN_DB" mariadb -u marzban -p"$DB_PASS" marzban -e "SELECT 1;" >/dev/null 2>&1; then
            echo -e "${RED}${CROSS}${NC} DB connection failed"
            echo -e "${YELLOW}${WARNING}${NC} Check password and container name"
            exit 1
        fi
        echo -e "${GREEN}${CHECK}${NC} DB connected"
        
        # Создание директории
        EXPORT_DIR="/root/marzban_export_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$EXPORT_DIR"
        cd "$EXPORT_DIR"
        
        # Экспорт пользователей
        echo -e "${CYAN}${INFO}${NC} Exporting users..."
        docker exec -i "$MARZBAN_DB" mariadb -u marzban -p"$DB_PASS" marzban -e "
        SELECT 
            u.id,
            u.username,
            u.status,
            IFNULL(u.used_traffic, 0) as used_traffic,
            IFNULL(u.data_limit, 0) as data_limit,
            IFNULL(u.expire, 0) as expire,
            u.created_at,
            u.data_limit_reset_strategy,
            IFNULL(u.note, '') as note,
            u.sub_updated_at,
            u.sub_last_user_agent,
            u.online_at,
            u.edit_at
        FROM users u
        ORDER BY u.created_at
        " -T > users_export.tsv 2>/dev/null || docker exec -i "$MARZBAN_DB" mariadb -u marzban -p"$DB_PASS" marzban -e "
        SELECT 
            'id', 'username', 'status', 'used_traffic', 'data_limit', 'expire', 'created_at', 'data_limit_reset_strategy', 'note', 'sub_updated_at', 'sub_last_user_agent', 'online_at', 'edit_at'
        UNION ALL
        SELECT 
            CAST(u.id AS CHAR),
            u.username,
            u.status,
            CAST(IFNULL(u.used_traffic, 0) AS CHAR),
            CAST(IFNULL(u.data_limit, 0) AS CHAR),
            CAST(IFNULL(u.expire, 0) AS CHAR),
            IFNULL(u.created_at, ''),
            IFNULL(u.data_limit_reset_strategy, ''),
            IFNULL(u.note, ''),
            IFNULL(u.sub_updated_at, ''),
            IFNULL(u.sub_last_user_agent, ''),
            IFNULL(u.online_at, ''),
            IFNULL(u.edit_at, '')
        FROM users u
        ORDER BY u.created_at
        " | sed 's/\t/\t/g' > users_export.tsv
        
        if [ ! -f "users_export.tsv" ]; then
            echo -e "${RED}${CROSS}${NC} Export failed"
            exit 1
        fi
        
        USER_COUNT=$(wc -l < users_export.tsv)
        
        if [ "$USER_COUNT" -eq 0 ]; then
            echo -e "${RED}${CROSS}${NC} No users found"
            exit 1
        fi
        
        echo -e "${GREEN}${CHECK}${NC} Exported: $USER_COUNT users"
        
        # Создание метаданных
        cat > migration_info.txt << METAEOF
Export Date: $(date)
Source: Marzban
Users Count: $USER_COUNT
METAEOF
        
        # Упаковка
        echo -e "${CYAN}${INFO}${NC} Creating archive..."
        tar -czf /root/migration_data.tar.gz -C "$EXPORT_DIR" .
        
        # Очистка
        cd /root
        rm -rf "$EXPORT_DIR"
        
        echo
        echo -e "${GREEN}${CHECK}${NC} EXPORT COMPLETED!"
        echo
        echo -e "${WHITE}Archive: /root/migration_data.tar.gz${NC}"
        echo -e "${WHITE}Users: $USER_COUNT${NC}"
        echo
        echo -e "${YELLOW}Next steps:${NC}"
        echo "1. Copy file to Remnawave server:"
        echo -e "   ${CYAN}scp /root/migration_data.tar.gz root@remnawave-ip:/root/${NC}"
        echo "2. Run script on Remnawave server"
        echo "3. Select IMPORT mode"
        echo
        ;;
        
    2)
        #==================
        # IMPORT MODE
        #==================
        
        echo
        echo -e "${GREEN}=== IMPORT MODE ===${NC}"
        echo
        
        # Проверка Remnawave
        if [ ! -d "/opt/remnawave" ]; then
            echo -e "${RED}${CROSS}${NC} Remnawave not found in /opt/remnawave"
            exit 1
        fi
        
        # Проверка архива
        if [ ! -f "/root/migration_data.tar.gz" ]; then
            echo -e "${RED}${CROSS}${NC} File not found: /root/migration_data.tar.gz"
            echo
            echo "Copy file from Marzban server:"
            echo -e "${CYAN}scp root@marzban-ip:/root/migration_data.tar.gz /root/${NC}"
            exit 1
        fi
        
        echo -e "${GREEN}${CHECK}${NC} Remnawave detected"
        echo -e "${GREEN}${CHECK}${NC} Archive found"
        
        # Распаковка
        IMPORT_DIR="/tmp/marzban_import_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$IMPORT_DIR"
        cd "$IMPORT_DIR"
        
        echo -e "${CYAN}${INFO}${NC} Extracting archive..."
        tar -xzf /root/migration_data.tar.gz
        
        if [ ! -f "users_export.tsv" ]; then
            echo -e "${RED}${CROSS}${NC} Invalid archive"
            exit 1
        fi
        
        USER_COUNT=$(wc -l < users_export.tsv)
        echo -e "${GREEN}${CHECK}${NC} Found: $USER_COUNT users"
        
        # Получение пароля БД
        echo -ne "${CYAN}Remnawave DB password: ${NC}"
        read -s DB_PASS
        echo
        
        if [ -z "$DB_PASS" ]; then
            echo -e "${RED}${CROSS}${NC} Password cannot be empty"
            exit 1
        fi
        
        # Проверка подключения
        echo -e "${CYAN}${INFO}${NC} Testing DB connection..."
        if ! docker exec -e PGPASSWORD="$DB_PASS" remnawave-db psql -U remnawave -d remnawave -c "SELECT 1;" >/dev/null 2>&1; then
            echo -e "${RED}${CROSS}${NC} DB connection failed"
            echo -e "${YELLOW}${WARNING}${NC} Check password and container name (remnawave-db)"
            exit 1
        fi
        echo -e "${GREEN}${CHECK}${NC} DB connected"
        
        # Создание резервной копии БД перед импортом
        echo -e "${CYAN}${INFO}${NC} Creating database backup..."
        BACKUP_FILE="/root/remnawave_backup_$(date +%Y%m%d_%H%M%S).sql"
        if docker exec -e PGPASSWORD="$DB_PASS" remnawave-db pg_dump -U remnawave remnawave > "$BACKUP_FILE" 2>/dev/null; then
            BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
            echo -e "${GREEN}${CHECK}${NC} Backup created: $BACKUP_FILE ($BACKUP_SIZE)"
            export BACKUP_FILE
        else
            echo -e "${YELLOW}${WARNING}${NC} Backup creation failed, but continuing..."
            BACKUP_FILE=""
        fi
        
        # Проверка существующих пользователей
        EXISTING_COUNT=$(docker exec -e PGPASSWORD="$DB_PASS" remnawave-db psql -U remnawave -d remnawave -t -c "SELECT COUNT(*) FROM users;" | tr -d ' ')
        if [ "$EXISTING_COUNT" -gt 0 ]; then
            echo -e "${YELLOW}${WARNING}${NC} Found $EXISTING_COUNT existing users in Remnawave"
            echo -ne "${CYAN}Continue with import? This will add new users (y/n): ${NC}"
            read CONFIRM
            if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
                echo -e "${RED}${CROSS}${NC} Import cancelled"
                exit 1
            fi
        fi
        
        # Установка зависимостей
        echo -e "${CYAN}${INFO}${NC} Installing dependencies..."
        if ! command -v python3 >/dev/null 2>&1; then
            echo -e "${RED}${CROSS}${NC} Python3 not found"
            exit 1
        fi
        
        if ! python3 -c "import psycopg2" 2>/dev/null; then
            apt-get update >/dev/null 2>&1
            if ! apt-get install -y python3-psycopg2 python3-pip >/dev/null 2>&1; then
                if command -v pip3 >/dev/null 2>&1; then
                    pip3 install psycopg2-binary >/dev/null 2>&1
                else
                    echo -e "${RED}${CROSS}${NC} Failed to install psycopg2"
                    exit 1
                fi
            fi
        fi
        
        # Создание Python скрипта
        cat > import_script.py << 'PYEOF'
#!/usr/bin/env python3
import csv
import uuid
import secrets
import string
import psycopg2
import sys
import os
from datetime import datetime, timedelta

def generate_password(length=20):
    alphabet = string.ascii_letters + string.digits
    return ''.join(secrets.choice(alphabet) for _ in range(length))

def status_mapping(status):
    if not status:
        return 'ACTIVE'
    status = str(status).lower().strip()
    mapping = {
        'active': 'ACTIVE',
        'expired': 'EXPIRED',
        'limited': 'LIMITED',
        'disabled': 'DISABLED',
        'on_hold': 'DISABLED',
        'onhold': 'DISABLED'
    }
    return mapping.get(status, 'ACTIVE')

def traffic_strategy_mapping(strategy):
    if not strategy:
        return 'NO_RESET'
    strategy = str(strategy).lower().strip()
    mapping = {
        'no_reset': 'NO_RESET',
        'day': 'DAY',
        'week': 'WEEK',
        'month': 'MONTH',
        'year': 'YEAR'
    }
    return mapping.get(strategy, 'NO_RESET')

def unix_to_timestamp(unix_time):
    if not unix_time or unix_time == 'NULL':
        return None
    try:
        return datetime.fromtimestamp(int(unix_time)).isoformat()
    except:
        return None

def mysql_datetime_to_iso(mysql_datetime):
    if not mysql_datetime or str(mysql_datetime) == 'NULL' or not str(mysql_datetime).strip():
        return None
    try:
        mysql_datetime = str(mysql_datetime).strip()
        for fmt in ['%Y-%m-%d %H:%M:%S', '%Y-%m-%d %H:%M:%S.%f', '%Y-%m-%d']:
            try:
                dt = datetime.strptime(mysql_datetime, fmt)
                return dt.isoformat()
            except:
                continue
        return None
    except:
        return None

try:
    conn = psycopg2.connect(
        host="127.0.0.1",
        port="6767",
        database="remnawave",
        user="remnawave",
        password=sys.argv[1]
    )
    cur = conn.cursor()
    print("✓ Connected to DB")
except Exception as e:
    print(f"✗ Connection failed: {e}")
    sys.exit(1)

print("Processing users...")
users = []

try:
    with open('users_export.tsv', 'r', encoding='utf-8') as f:
        lines = f.readlines()
        if not lines:
            print("✗ Empty export file")
            sys.exit(1)
        
        header_line = lines[0].strip()
        if not header_line.startswith('id\t') and 'username' not in header_line:
            fieldnames = ['id', 'username', 'status', 'used_traffic', 'data_limit', 'expire', 'created_at', 'data_limit_reset_strategy', 'note', 'sub_updated_at', 'sub_last_user_agent', 'online_at', 'edit_at']
            lines = [header_line] + lines[1:]
        else:
            fieldnames = None
        
        reader = csv.DictReader(lines, delimiter='\t', fieldnames=fieldnames)
        if fieldnames:
            next(reader)
        
        for row in reader:
            if not row.get('username'):
                continue
            user_uuid = str(uuid.uuid4())
            short_uuid = secrets.token_urlsafe(16)[:16]
            
            expire_at = None
            expire_value = row.get('expire', '0')
            if expire_value and str(expire_value) != 'NULL' and str(expire_value) != '0' and str(expire_value).strip():
                try:
                    expire_at = unix_to_timestamp(str(expire_value))
                except:
                    expire_at = None
            if not expire_at:
                expire_at = (datetime.now() + timedelta(days=36500)).isoformat()
            
            traffic_limit = 0
            data_limit_value = row.get('data_limit', '0')
            if data_limit_value and str(data_limit_value) != 'NULL' and str(data_limit_value).strip():
                try:
                    traffic_limit = int(float(str(data_limit_value)))
                except:
                    traffic_limit = 0
            
            used_traffic = 0
            used_traffic_value = row.get('used_traffic', '0')
            if used_traffic_value and str(used_traffic_value) != 'NULL' and str(used_traffic_value).strip():
                try:
                    used_traffic = int(float(str(used_traffic_value)))
                except:
                    used_traffic = 0
            
            user = {
                'uuid': user_uuid,
                'short_uuid': short_uuid,
                'username': row['username'],
                'status': status_mapping(row['status']),
                'used_traffic_bytes': used_traffic,
                'traffic_limit_bytes': traffic_limit,
                'traffic_limit_strategy': traffic_strategy_mapping(row['data_limit_reset_strategy']),
                'sub_last_user_agent': row.get('sub_last_user_agent') if row.get('sub_last_user_agent') and str(row.get('sub_last_user_agent')) != 'NULL' else None,
                'sub_last_opened_at': mysql_datetime_to_iso(row.get('sub_updated_at', '')),
                'expire_at': expire_at,
                'online_at': mysql_datetime_to_iso(row.get('online_at', '')),
                'created_at': mysql_datetime_to_iso(row.get('created_at', '')) or datetime.now().isoformat(),
                'updated_at': mysql_datetime_to_iso(row.get('edit_at', '')) or mysql_datetime_to_iso(row.get('created_at', '')) or datetime.now().isoformat(),
                'lifetime_used_traffic_bytes': used_traffic,
                'description': row.get('note') if row.get('note') and str(row.get('note')) != 'NULL' and str(row.get('note')).strip() else None,
                'trojan_password': generate_password(),
                'vless_uuid': str(uuid.uuid4()),
                'ss_password': generate_password(32),
                'last_triggered_threshold': 0
            }
            users.append(user)
except Exception as e:
    print(f"✗ Processing error: {e}")
    sys.exit(1)

print(f"Importing {len(users)} users...")

columns = [
    'uuid', 'short_uuid', 'username', 'status',
    'used_traffic_bytes', 'traffic_limit_bytes', 'traffic_limit_strategy',
    'sub_last_user_agent', 'sub_last_opened_at', 'expire_at', 'online_at',
    'created_at', 'updated_at', 'lifetime_used_traffic_bytes', 'description',
    'trojan_password', 'vless_uuid', 'ss_password', 'last_triggered_threshold'
]

query = f"INSERT INTO users ({', '.join(columns)}) VALUES ({', '.join(['%s'] * len(columns))})"

imported = 0
skipped = 0

conn.autocommit = False

for user in users:
    try:
        cur.execute("SELECT uuid FROM users WHERE username = %s", (user['username'],))
        if cur.fetchone():
            print(f"⚠ Skipping duplicate username: {user['username']}")
            skipped += 1
            continue
        
        values = [user.get(col) for col in columns]
        cur.execute(query, values)
        imported += 1
        
        if imported % 100 == 0:
            conn.commit()
            print(f"  Progress: {imported} users imported...")
    except psycopg2.IntegrityError as e:
        print(f"⚠ Integrity error for {user['username']}: {e}")
        skipped += 1
        conn.rollback()
    except Exception as e:
        print(f"✗ Error importing {user['username']}: {e}")
        skipped += 1
        conn.rollback()

conn.commit()
print(f"✓ Imported: {imported}")
if skipped > 0:
    print(f"⚠ Skipped: {skipped}")

print("Linking to squad...")
cur.execute("SELECT uuid FROM internal_squads LIMIT 1")
squad = cur.fetchone()

if not squad:
    print("⚠ No squad found! Users will not be linked to any squad.")
    print("  You can link them manually in the panel.")
    linked = 0
else:
    squad_uuid = squad[0]
    print(f"Squad: {squad_uuid}")

    linked = 0
    for user in users:
        try:
            cur.execute(
                "INSERT INTO internal_squad_members (internal_squad_uuid, user_uuid) VALUES (%s, %s) ON CONFLICT DO NOTHING",
                (squad_uuid, user['uuid'])
            )
            if cur.rowcount > 0:
                linked += 1
        except psycopg2.IntegrityError:
            pass
        except Exception as e:
            print(f"⚠ Error linking {user['username']}: {e}")

    conn.commit()
    print(f"✓ Linked: {linked} users to squad")

report_file = '/root/migration_report.txt'
with open(report_file, 'w', encoding='utf-8') as f:
    f.write(f"MIGRATION REPORT\n")
    f.write(f"================\n")
    f.write(f"Date: {datetime.now()}\n\n")
    f.write(f"Imported: {imported}\n")
    f.write(f"Skipped: {skipped}\n")
    if linked > 0:
        f.write(f"Linked to squad: {linked}\n\n")
        f.write(f"Squad UUID: {squad_uuid}\n\n")
    else:
        f.write(f"Linked to squad: 0 (no squad found)\n\n")
    f.write(f"IMPORTANT:\n")
    f.write(f"- Subscription URLs changed\n")
    f.write(f"- Users need new links from Remnawave\n")
    f.write(f"- Backup created at: {os.environ.get('BACKUP_FILE', 'N/A')}\n")

cur.close()
conn.close()
print("✓ Import completed!")
PYEOF
        
        # Запуск импорта
        echo -e "${CYAN}${INFO}${NC} Running import..."
        chmod +x import_script.py
        export BACKUP_FILE
        
        if python3 import_script.py "$DB_PASS"; then
            echo
            echo -e "${GREEN}${CHECK}${NC} IMPORT COMPLETED!"
            echo
            
            # Статистика
            TOTAL=$(docker exec -e PGPASSWORD="$DB_PASS" remnawave-db psql -U remnawave -d remnawave -t -c "SELECT COUNT(*) FROM users;" | tr -d ' ')
            echo -e "${WHITE}Total users in Remnawave: $TOTAL${NC}"
            
            # Отчет
            if [ -f "/root/migration_report.txt" ]; then
                echo
                cat /root/migration_report.txt
            fi
            
            # Перезапуск
            echo
            echo -e "${CYAN}${INFO}${NC} Restarting Remnawave..."
            cd /opt/remnawave
            docker compose restart >/dev/null 2>&1
            sleep 5
            echo -e "${GREEN}${CHECK}${NC} Remnawave restarted"
            
            # Очистка
            cd /root
            echo -e "${CYAN}${INFO}${NC} Cleaning up temporary files..."
            rm -rf "$IMPORT_DIR"
            rm -f import_script.py 2>/dev/null
            
        else
            echo -e "${RED}${CROSS}${NC} Import failed"
            echo -e "${YELLOW}${WARNING}${NC} Check the error messages above"
            echo -e "${CYAN}${INFO}${NC} Backup available at: $BACKUP_FILE"
            echo -e "${CYAN}${INFO}${NC} Temporary files kept in: $IMPORT_DIR"
            exit 1
        fi
        ;;
        
    *)
        echo -e "${RED}${CROSS}${NC} Invalid choice"
        exit 1
        ;;
esac

echo
echo -e "${GREEN}${CHECK}${NC} Done!"
echo
