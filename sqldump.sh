#!/bin/bash

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Detect if running in Docker or native
detect_db_host() {
    if docker ps --format '{{.Names}}' | grep -q "ac-database"; then
        echo "ac-database"
    else
        echo "127.0.0.1"
    fi
}

DB_HOST=$(detect_db_host)
DB_PORT=3306
DB_USER="root"

# Try to get password from .env file if it exists
if [ -f "src/.env" ]; then
    DEFAULT_PASSWORD=$(grep -E "^MYSQL_ROOT_PASSWORD=" src/.env 2>/dev/null | cut -d'=' -f2)
fi

if [ -n "$DEFAULT_PASSWORD" ] && [ "$DEFAULT_PASSWORD" != "password" ]; then
    print_status "Using password from src/.env"
    password="$DEFAULT_PASSWORD"
else
    read -sp "Enter mysql root password: " password
    echo ""
fi

# Test database connection
test_connection() {
    docker exec -i ac-database mysqladmin -u"$DB_USER" -p"$password" ping &>/dev/null 2>&1
    return $?
}

if ! test_connection; then
    print_error "Cannot connect to database. Is the container running?"
    print_status "Try: cd azerothcore-wotlk && docker compose up -d"
    exit 1
fi

BACKUP_DIR="sql_dumps"

function show_help() {
    echo ""
    echo -e "${GREEN}AzerothCore Database Backup/Restore Tool${NC}"
    echo ""
    echo "Usage: ./sqldump.sh [OPTION]"
    echo ""
    echo "Options:"
    echo "  -b, --backup              Create a backup of all databases"
    echo "  -r, --restore DATE        Restore databases from a specific date (YYYY-MM-DD)"
    echo "  -l, --list                List available backups"
    echo "  -h, --help                Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./sqldump.sh --backup                      # Create backup with today's date"
    echo "  ./sqldump.sh --restore 2024-01-15          # Restore from 2024-01-15 backup"
    echo "  ./sqldump.sh --list                        # Show all available backups"
    echo ""
}

function list_backups() {
    if [ ! -d "$BACKUP_DIR" ]; then
        print_warning "No backups directory found"
        return
    fi
    
    echo ""
    echo -e "${GREEN}Available backups:${NC}"
    echo ""
    
    for db in acore_auth acore_characters acore_world acore_playerbots; do
        if [ -d "$BACKUP_DIR/$db" ]; then
            echo -e "${BLUE}$db:${NC}"
            ls -1 "$BACKUP_DIR/$db"/*.sql 2>/dev/null | sed 's|.*/||' | sed 's/\.sql$//' | sed 's/^.*-//' | sort -r | while read date; do
                echo "  - $date"
            done
            echo ""
        fi
    done
}

function create_backup() {
    print_status "Creating backup..."
    
    # Create backup directories if they don't exist
    for db in acore_auth acore_characters acore_world acore_playerbots; do
        mkdir -p "$BACKUP_DIR/$db"
    done
    
    local backup_date=$(date +%F)
    local backup_time=$(date +%H-%M-%S)
    
    # Backup each database
    for db in acore_auth acore_characters acore_world acore_playerbots; do
        print_status "Backing up $db..."
        docker exec ac-database mysqldump -u"$DB_USER" -p"$password" "$db" > "$BACKUP_DIR/$db/${db}-${backup_date}.sql" 2>/dev/null
        
        if [ $? -eq 0 ] && [ -s "$BACKUP_DIR/$db/${db}-${backup_date}.sql" ]; then
            print_success "  → $BACKUP_DIR/$db/${db}-${backup_date}.sql"
        else
            print_error "  → Failed to backup $db"
        fi
    done
    
    # Create a backup info file
    cat > "$BACKUP_DIR/backup-${backup_date}.info" << EOF
Backup Date: $backup_date
Backup Time: $backup_time
Databases: acore_auth, acore_characters, acore_world, acore_playerbots
Server: $(hostname)
EOF
    
    echo ""
    print_success "Backup completed successfully!"
    print_status "Backup saved to: $BACKUP_DIR/"
}

function restore_backup() {
    local recover_date=$1
    
    # Validate date format
    if ! [[ "$recover_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        print_error "Invalid date format. Use YYYY-MM-DD"
        exit 1
    fi
    
    # Check if backup files exist
    local missing_files=0
    for db in acore_auth acore_characters acore_world acore_playerbots; do
        if [ ! -f "$BACKUP_DIR/$db/${db}-${recover_date}.sql" ]; then
            print_error "Missing backup: $BACKUP_DIR/$db/${db}-${recover_date}.sql"
            missing_files=1
        fi
    done
    
    if [ $missing_files -eq 1 ]; then
        print_error "Cannot restore. Some backup files are missing."
        print_status "Use --list to see available backups"
        exit 1
    fi
    
    print_warning "This will OVERWRITE your current database!"
    ask_user "Are you sure you want to restore from $recover_date?" "recover"
    if [ $? -ne 0 ]; then
        print_status "Restore cancelled."
        exit 0
    fi
    
    print_status "Stopping world server..."
    docker stop ac-worldserver 2>/dev/null
    
    print_status "Restoring databases..."
    
    # Restore each database
    for db in acore_auth acore_characters acore_world acore_playerbots; do
        print_status "Restoring $db..."
        docker exec -i ac-database mysql -u"$DB_USER" -p"$password" "$db" < "$BACKUP_DIR/$db/${db}-${recover_date}.sql" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            print_success "  → $db restored"
        else
            print_error "  → Failed to restore $db"
        fi
    done
    
    print_status "Restarting world server..."
    docker start ac-worldserver 2>/dev/null
    
    echo ""
    print_success "Restore completed from backup: $recover_date"
}

# Enhanced ask_user function for restore confirmation
function ask_user() {
    local prompt="$1"
    local expected="$2"
    
    if [ "$expected" = "recover" ]; then
        read -p "$(echo -e ${YELLOW}"$prompt (y/n): "${NC})" choice
        case "$choice" in
            y|Y ) return 0;;
            * ) return 1;;
        esac
    fi
}

# parse the argv[] (command line arguments)
case "${1:-}" in
    -b|--backup)
        create_backup
        ;;
    -r|--restore)
        if [ -z "$2" ]; then
            print_error "Please specify a date (YYYY-MM-DD)"
            echo ""
            list_backups
            exit 1
        fi
        restore_backup "$2"
        ;;
    -l|--list)
        list_backups
        ;;
    -h|--help|"")
        show_help
        ;;
    *)
        print_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac
