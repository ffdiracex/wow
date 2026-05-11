#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [ ! -d "azerothcore-wotlk" ]; then
    print_error "AzerothCore not found. Run setup.sh first."
    exit 1
fi

print_status "Stopping containers..."
cd azerothcore-wotlk
docker compose down

print_status "Updating AzerothCore..."
git pull origin Playerbot

print_status "Updating mod-playerbots..."
cd modules/mod-playerbots
git pull origin master
cd ../..

print_status "Updating optional modules..."
for mod in modules/mod-*; do
    if [ -d "$mod/.git" ]; then
        print_status "Updating $(basename $mod)..."
        cd "$mod" && git pull && cd ../..
    fi
done

print_status "Rebuilding containers..."
docker compose up -d --build

cd ..

print_success "Update complete!"
print_status "Run 'docker attach ac-worldserver' to verify"
