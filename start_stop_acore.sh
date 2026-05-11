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

# Container names
CONTAINERS=("ac-worldserver" "ac-authserver" "ac-database")
COMPOSE_DIR="azerothcore-wotlk"

# Function to check if containers exist (not just running)
containers_exist() {
    for container in "${CONTAINERS[@]}"; do
        if ! docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
            return 1
        fi
    done
    return 0
}

# Function to check if containers are running
containers_running() {
    for container in "${CONTAINERS[@]}"; do
        if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            return 1
        fi
    done
    return 0
}

# Function to show container status
show_status() {
    echo ""
    echo -e "${GREEN}Container Status:${NC}"
    echo "─────────────────────────────────"
    for container in "${CONTAINERS[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            local status=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null)
            echo -e "  ${GREEN}●${NC} $container: ${GREEN}running${NC} ($status)"
        elif docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
            local status=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null)
            echo -e "  ${YELLOW}○${NC} $container: ${YELLOW}stopped${NC} ($status)"
        else
            echo -e "  ${RED}✗${NC} $container: ${RED}does not exist${NC}"
        fi
    done
    echo "─────────────────────────────────"
    echo ""
}

# Main logic
manage_docker_containers() {
    # Check if Docker is running
    if ! docker info &>/dev/null; then
        print_error "Docker is not running. Start Docker first:"
        echo "  sudo systemctl start docker"
        exit 1
    fi
    
    # Check if containers exist at all
    if ! containers_exist; then
        print_warning "Containers don't exist yet. Starting with docker compose..."
        if [ -d "$COMPOSE_DIR" ]; then
            cd "$COMPOSE_DIR" || exit 1
            docker compose up -d
            cd ..
            print_success "Containers started via docker compose"
            show_status
        else
            print_error "Directory $COMPOSE_DIR not found. Run setup.sh first."
            exit 1
        fi
        return
    fi
    
    # Toggle containers: stop if running, start if stopped
    if containers_running; then
        print_status "Stopping containers: ${CONTAINERS[*]}"
        for container in "${CONTAINERS[@]}"; do
            if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
                docker stop "$container" &>/dev/null
                print_success "  → Stopped $container"
            fi
        done
    else
        print_status "Starting containers: ${CONTAINERS[*]}"
        for container in "${CONTAINERS[@]}"; do
            if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
                docker start "$container" &>/dev/null
                print_success "  → Started $container"
            fi
        done
    fi
    
    show_status
}

# Add command-line argument support
case "${1:-}" in
    -s|--status)
        show_status
        ;;
    -d|--down)
        print_status "Stopping and removing containers..."
        if [ -d "$COMPOSE_DIR" ]; then
            cd "$COMPOSE_DIR" && docker compose down && cd ..
        else
            for container in "${CONTAINERS[@]}"; do
                docker stop "$container" 2>/dev/null
                docker rm "$container" 2>/dev/null
            done
        fi
        print_success "Containers stopped and removed"
        ;;
    -h|--help)
        echo "Usage: ./start_stop_acore.sh [OPTION]"
        echo ""
        echo "Options:"
        echo "  (no option)   Toggle containers (start if stopped, stop if running)"
        echo "  -s, --status  Show current container status only"
        echo "  -d, --down    Stop and remove containers (full shutdown)"
        echo "  -h, --help    Show this help message"
        ;;
    *)
        manage_docker_containers
        ;;
esac
