#!/bin/bash

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

function ask_user() {
    read -p "$(echo -e ${YELLOW}"$1 (y/n): "${NC})" choice
    case "$choice" in
        y|Y ) return 0;;
        * ) return 1;;
    esac
}

# Check if running on Arch
if ! grep -qi "arch" /etc/os-release; then
    print_error "This script is designed for Arch Linux only!"
    exit 1
fi

print_status "Setting up AzerothCore with Playerbots on Arch Linux..."

# Create necessary directories
mkdir -p src/sql/{acore_auth,acore_world,acore_characters}
mkdir -p wotlk/etc/modules

# Set timezone from system
if [ -f /etc/timezone ]; then
    sed -i "s|^TZ=.*$|TZ=$(cat /etc/timezone)|" src/.env 2>/dev/null || true
else
    # Arch uses /etc/localtime symlink
    TZ=$(readlink /etc/localtime | sed 's|/usr/share/zoneinfo/||')
    sed -i "s|^TZ=.*$|TZ=$TZ|" src/.env 2>/dev/null || true
fi

# Check and install MariaDB client (Arch uses mariadb package)
if ! command -v mysql &> /dev/null; then
    print_status "MariaDB client not found. Installing..."
    sudo pacman -S --noconfirm mariadb-clients
    print_success "MariaDB client installed"
else
    print_success "MariaDB client already installed"
fi

# Check and install Docker for Arch
if ! command -v docker &> /dev/null; then
    print_status "Docker not found. Installing Docker for Arch Linux..."
    sudo pacman -S --noconfirm docker docker-compose docker-buildx
    sudo systemctl enable docker.service
    sudo systemctl start docker.service
    sudo usermod -aG docker $USER
    print_warning "Added user to docker group. Please log out and back in, then rerun setup.sh"
    exit 1
else
    print_success "Docker already installed"
fi

# Ensure Docker daemon is running
if ! systemctl is-active --quiet docker; then
    print_status "Starting Docker daemon..."
    sudo systemctl start docker
fi

# Check Docker Compose plugin
if ! docker compose version &> /dev/null; then
    print_error "Docker Compose plugin not found. Installing..."
    sudo pacman -S --noconfirm docker-compose
fi

# Function to install AzerothCore
install_azerothcore() {
    print_status "Cloning AzerothCore Playerbots branch..."
    git clone https://github.com/liyunfan1223/azerothcore-wotlk.git --branch=Playerbot
    
    if [ ! -d "azerothcore-wotlk" ]; then
        print_error "Failed to clone AzerothCore"
        exit 1
    fi
    
    cp src/.env azerothcore-wotlk/
    cp src/*.yml azerothcore-wotlk/
    
    cd azerothcore-wotlk/modules
    print_status "Cloning mod-playerbots..."
    git clone https://github.com/liyunfan1223/mod-playerbots.git --branch=master
    cd ..
}

# Check if AzerothCore exists and handle updates
if [ -d "azerothcore-wotlk" ]; then
    print_status "Existing AzerothCore found"
    
    destination_dir="../data/sql/custom"  # Adjust path for Arch structure
    
    world="$destination_dir/db_world/"
    chars="$destination_dir/db_characters/"
    auth="$destination_dir/db_auth/"
    
    cd azerothcore-wotlk
    
    # Clean old SQL files if they exist
    [ -d "$world" ] && rm -rf "$world"/*.sql
    [ -d "$chars" ] && rm -rf "$chars"/*.sql
    [ -d "$auth" ] && rm -rf "$auth"/*.sql
    
    cd ..
    
    cp src/.env azerothcore-wotlk/
    cp src/*.yml azerothcore-wotlk/
    cd azerothcore-wotlk
else
    if ask_user "Download and install AzerothCore Playerbots?"; then
        install_azerothcore
        cd azerothcore-wotlk
    else
        print_error "Aborted by user"
        exit 1
    fi
fi

# Install optional modules
if ask_user "Install optional modules?"; then
    cd modules
    
    function install_mod() {
        local mod_name=$1
        local repo_url=$2
        
        if [ -d "${mod_name}" ]; then
            print_status "${mod_name} exists. Skipping..."
        else
            if ask_user "Install ${mod_name}?"; then
                print_status "Cloning ${mod_name}..."
                git clone "${repo_url}"
                print_success "${mod_name} installed"
            fi
        fi
    }
    
    install_mod "mod-aoe-loot" "https://github.com/azerothcore/mod-aoe-loot.git"
    install_mod "mod-learn-spells" "https://github.com/noisiver/mod-learnspells.git"
    install_mod "mod-fireworks-on-level" "https://github.com/azerothcore/mod-fireworks-on-level.git"
    install_mod "mod-individual-progression" "https://github.com/ZhengPeiRu21/mod-individual-progression.git"
    
    cd ..
fi

# Build and start containers
print_status "Building and starting Docker containers..."
docker compose up -d --build

cd ..

# Fix permissions for Arch (UID 1000 is typical for first user)
print_status "Setting permissions..."
sudo chown -R 1000:1000 wotlk

# Directory for custom SQL files
custom_sql_dir="src/sql"
auth_db="acore_auth"
world_db="acore_world"
chars_db="acore_characters"

# Get LAN IP (prefer 192.168.* or 10.* over 172.* docker networks)
ip_address=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\|^172\.1[6789]\|^172\.2[0-9]\|^172\.3[01]' | head -n1)
if [ -z "$ip_address" ]; then
    ip_address=$(hostname -I | awk '{print $1}')
fi
print_success "Server will be accessible at: $ip_address"

# Function to execute SQL files with IP replacement
function execute_sql() {
    local db_name=$1
    local sql_dir="$custom_sql_dir/$db_name"
    
    if [ -d "$sql_dir" ]; then
        for custom_sql_file in "$sql_dir"/*.sql; do
            if [ -f "$custom_sql_file" ]; then
                print_status "Executing $(basename "$custom_sql_file") on $db_name..."
                temp_sql_file=$(mktemp)
                if [[ "$(basename "$custom_sql_file")" == "update_realmlist.sql" ]]; then
                    sed -e "s/{{IP_ADDRESS}}/$ip_address/g" "$custom_sql_file" > "$temp_sql_file"
                else
                    cp "$custom_sql_file" "$temp_sql_file"
                fi
                mysql -h "$ip_address" -uroot -ppassword "$db_name" < "$temp_sql_file" 2>/dev/null || \
                    print_warning "Failed to execute $custom_sql_file (database may not be ready)"
                rm -f "$temp_sql_file"
            fi
        done
    else
        print_status "No SQL files found in $sql_dir, skipping..."
    fi
}

# Run custom SQL files
print_status "Running custom SQL files..."
execute_sql "$auth_db"
execute_sql "$world_db"
execute_sql "$chars_db"

# Create Playerbots config directory and copy default config
if [ -f "azerothcore-wotlk/modules/mod-playerbots/conf/playerbots.conf.dist" ]; then
    print_status "Copying Playerbots configuration..."
    cp azerothcore-wotlk/modules/mod-playerbots/conf/playerbots.conf.dist wotlk/etc/modules/playerbots.conf
    print_success "Playerbots config available at wotlk/etc/modules/playerbots.conf"
fi

# Final output
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                    SETUP COMPLETE!                         ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}IMPORTANT NOTES:${NC}"
echo ""
echo "1. Attach to world server console:"
echo -e "   ${BLUE}docker attach ac-worldserver${NC}"
echo ""
echo "2. Create your GM account (at AC> prompt):"
echo -e "   ${BLUE}account create YourUsername YourPassword${NC}"
echo -e "   ${BLUE}account set gmlevel YourUsername 3 -1${NC}"
echo ""
echo "3. Detach from console without stopping:"
echo -e "   ${BLUE}Ctrl+p Ctrl+q${NC}"
echo ""
echo "4. Configure your WoW client's realmlist.wtf:"
echo -e "   ${BLUE}set realmlist $ip_address${NC}"
echo ""
echo "5. All configuration files are in the ${BLUE}wotlk/${NC} folder"
echo "   - Server config: ${BLUE}wotlk/etc/worldserver.conf${NC}"
echo "   - Playerbots config: ${BLUE}wotlk/etc/modules/playerbots.conf${NC}"
echo ""
echo "6. To stop the server:"
echo -e "   ${BLUE}cd azerothcore-wotlk && docker compose down${NC}"
echo ""
echo "7. To update later:"
echo -e "   ${BLUE}./update.sh${NC}"
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
