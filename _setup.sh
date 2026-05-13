#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

ask_user() {
    read -p "$(echo -e ${YELLOW}"$1 (y/n): "${NC})" choice
    case "$choice" in
        y|Y ) return 0;;
        * ) return 1;;
    esac
}

# Create the src directory and .env file if they don't exist
mkdir -p src

if [ ! -f "src/.env" ]; then
    print_status "Creating src/.env file with default values..."
    cat > src/.env << 'EOF'
# Database Configuration
MYSQL_ROOT_PASSWORD=password
MYSQL_DATABASE=acore
MYSQL_USER=acore
MYSQL_PASSWORD=acore

# Server Configuration
TZ=UTC
EOF
    print_success "src/.env created"
fi

# Load environment variables
source src/.env

# Clean up any stale docker-compose PID file
if [ -f /tmp/docker-compose.pid ]; then
    print_warning "Removing stale docker-compose.pid file"
    sudo rm -f /tmp/docker-compose.pid
fi

# Clean up any stale docker-compose containers from previous runs
if [ -f "azerothcore-wotlk/docker-compose.yml" ]; then
    cd azerothcore-wotlk
    docker compose down 2>/dev/null
    cd ..
fi

# Check and install MariaDB client
if ! command -v mysql &> /dev/null; then
    print_status "Installing mariadb-clients..."
    sudo pacman -S --noconfirm mariadb-clients
    print_success "MariaDB client installed"
fi

# Check and install Docker
if ! command -v docker &> /dev/null; then
    print_status "Installing Docker..."
    sudo pacman -S --noconfirm docker docker-compose docker-buildx
    sudo systemctl enable docker.service
    sudo systemctl start docker.service
    print_success "Docker installed"
fi

# Ensure Docker daemon is running
if ! systemctl is-active --quiet docker; then
    print_status "Starting Docker daemon..."
    sudo systemctl start docker
fi

# Check if user is in docker group
if ! groups $USER | grep -q docker; then
    print_warning "User not in docker group. Adding..."
    sudo usermod -aG docker $USER
    print_warning "Please log out and back in, then rerun this script"
    exit 1
fi

# Function to install AzerothCore
install_azerothcore() {
    print_status "Cloning AzerothCore Playerbots branch..."
    git clone https://github.com/liyunfan1223/azerothcore-wotlk.git --branch=Playerbot
    
    if [ ! -d "azerothcore-wotlk" ]; then
        print_error "Failed to clone AzerothCore"
        exit 1
    fi
    
    # Copy configuration files
    cp src/.env azerothcore-wotlk/ 2>/dev/null || true
    
    cd azerothcore-wotlk/modules
    print_status "Cloning mod-playerbots..."
    git clone https://github.com/liyunfan1223/mod-playerbots.git --branch=master
    cd ../..
}

# Check if AzerothCore exists
if [ -d "azerothcore-wotlk" ]; then
    print_status "Existing AzerothCore found"
    
    # Clean old SQL files from custom directory
    if [ -d "azerothcore-wotlk/data/sql/custom" ]; then
        rm -rf azerothcore-wotlk/data/sql/custom/db_world/*.sql 2>/dev/null
        rm -rf azerothcore-wotlk/data/sql/custom/db_characters/*.sql 2>/dev/null
        rm -rf azerothcore-wotlk/data/sql/custom/db_auth/*.sql 2>/dev/null
    fi
    
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
    
    install_mod() {
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
    
    cd ..
fi

# Create docker-compose.override.yml for module mounting
if [ ! -f "docker-compose.override.yml" ]; then
    print_status "Creating docker-compose.override.yml..."
    cat > docker-compose.override.yml << 'EOF'
services:
  ac-worldserver:
    volumes:
      - ./modules:/azerothcore/modules:ro
EOF
    print_success "docker-compose.override.yml created"
fi

# Build and start containers
print_status "Building and starting Docker containers..."
docker compose up -d --build

cd ..

# Create wotlk directory and fix permissions
mkdir -p wotlk/etc/modules

# Fix permissions for the container user (UID 1000)
print_status "Fixing file permissions..."
sudo chown -R 1000:1000 wotlk 2>/dev/null || true
sudo chown -R 1000:1000 azerothcore-wotlk/env/dist/etc 2>/dev/null || true

# Get LAN IP
ip_address=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\|^172\.1[6789]\|^172\.2[0-9]\|^172\.3[01]' | head -n1)
if [ -z "$ip_address" ]; then
    ip_address=$(hostname -I | awk '{print $1}')
fi

print_success "Server will be accessible at: $ip_address"

# Copy Playerbots config if it exists
if [ -f "azerothcore-wotlk/modules/mod-playerbots/conf/playerbots.conf.dist" ]; then
    cp azerothcore-wotlk/modules/mod-playerbots/conf/playerbots.conf.dist wotlk/etc/modules/playerbots.conf
    print_success "Playerbots config copied to wotlk/etc/modules/playerbots.conf"
fi

# Final output
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                    SETUP COMPLETE!                         ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}NEXT STEPS:${NC}"
echo ""
echo "1. Attach to world server console:"
echo -e "   ${BLUE}cd azerothcore-wotlk && docker attach ac-worldserver${NC}"
echo ""
echo "2. Create your GM account (at AC> prompt):"
echo -e "   ${BLUE}account create YourUsername YourPassword${NC}"
echo -e "   ${BLUE}account set gmlevel YourUsername 3 -1${NC}"
echo ""
echo "3. Detach from console:"
echo -e "   ${BLUE}Ctrl+P then Ctrl+Q${NC}"
echo ""
echo "4. Configure your WoW client's realmlist.wtf:"
echo -e "   ${BLUE}set realmlist $ip_address${NC}"
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
