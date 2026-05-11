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

# Function to ask for confirmation
ask_user() {
    read -p "$(echo -e ${YELLOW}"$1 (y/n): "${NC})" choice
    case "$choice" in
        y|Y ) return 0;;
        * ) return 1;;
    esac
}

# Check if AzerothCore directory exists
if [ ! -d "azerothcore-wotlk" ]; then
    print_error "azerothcore-wotlk directory not found!"
    print_status "Are you in the correct directory?"
    exit 1
fi

destination_dir="azerothcore-wotlk/data/sql/custom"

world="$destination_dir/db_world"
chars="$destination_dir/db_characters"
auth="$destination_dir/db_auth"

# Check if directories exist before attempting to clean
missing_dirs=0
for dir in "$world" "$chars" "$auth"; do
    if [ ! -d "$dir" ]; then
        print_warning "Directory not found: $dir"
        missing_dirs=1
    fi
done

if [ $missing_dirs -eq 1 ]; then
    print_error "Some directories are missing. Nothing to clean."
    
    # Offer to create them?
    if ask_user "Would you like to create the missing directories?"; then
        mkdir -p "$world" "$chars" "$auth"
        print_success "Created directories"
    else
        exit 1
    fi
fi

# Count files before deletion
world_count=$(find "$world" -maxdepth 1 -name "*.sql" 2>/dev/null | wc -l)
chars_count=$(find "$chars" -maxdepth 1 -name "*.sql" 2>/dev/null | wc -l)
auth_count=$(find "$auth" -maxdepth 1 -name "*.sql" 2>/dev/null | wc -l)
total_count=$((world_count + chars_count + auth_count))

if [ $total_count -eq 0 ]; then
    print_status "No SQL files found to clean"
    exit 0
fi

echo ""
print_warning "Found $total_count SQL files to delete:"
echo "  - db_world: $world_count files"
echo "  - db_characters: $chars_count files"
echo "  - db_auth: $auth_count files"
echo ""

if ask_user "Delete these SQL files?"; then
    cd azerothcore-wotlk || exit 1
    
    # Delete files with verbose output
    if [ -d "$world" ]; then
        rm -rf "$world"/*.sql 2>/dev/null
        print_success "Cleaned: $world/*.sql"
    fi
    
    if [ -d "$chars" ]; then
        rm -rf "$chars"/*.sql 2>/dev/null
        print_success "Cleaned: $chars/*.sql"
    fi
    
    if [ -d "$auth" ]; then
        rm -rf "$auth"/*.sql 2>/dev/null
        print_success "Cleaned: $auth/*.sql"
    fi
    
    cd ..
    echo ""
    print_success "Custom SQL cleanup complete!"
else
    print_status "Cleanup cancelled"
    exit 0
fi
