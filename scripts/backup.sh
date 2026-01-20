#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# Configuration
BACKUP_DIR="$PROJECT_ROOT/backup"
DOCKER_ENV_PATH="$PROJECT_ROOT/.env.local"
COMPOSE_CMD="docker compose"
COMPOSE_FILES="-f docker-compose.production.yml"
BACKUP_RETENTION_DAYS=7

# Function to display messages
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to safely get a variable value from .env.local
get_env_var() {
    local var_name="$1"
    if [ -f "$DOCKER_ENV_PATH" ]; then
        grep "^${var_name}=" "$DOCKER_ENV_PATH" 2>/dev/null | sed "s/^${var_name}=//" | sed 's/^["'\'']//; s/["'\'']$//' | head -1
    fi
}

# Function to check if backup is needed (no backup in last 7 days)
should_run_backup() {
    if [ ! -d "$BACKUP_DIR" ]; then
        return 0  # Backup directory doesn't exist, need backup
    fi
    
    local backup_count=$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
    if [ "$backup_count" -eq 0 ]; then
        return 0  # No backups found, need backup
    fi
    
    # Find the most recent backup
    local latest_backup=$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
    
    if [ -z "$latest_backup" ]; then
        return 0  # No backups found, need backup
    fi
    
    # Get modification time of latest backup
    local latest_time=$(stat -c %Y "$latest_backup" 2>/dev/null || stat -f %m "$latest_backup" 2>/dev/null)
    local current_time=$(date +%s)
    local days_since_backup=$(( (current_time - latest_time) / 86400 ))
    
    if [ "$days_since_backup" -ge "$BACKUP_RETENTION_DAYS" ]; then
        return 0  # Last backup is older than 7 days, need backup
    fi
    
    return 1  # Recent backup exists, skip
}

# Function to backup PostgreSQL database
backup_db_pg_dump() {
    local backup_dir=$1
    local pu pdb ppw cid
    
    pu=$(get_env_var "POSTGRES_USER")
    pdb=$(get_env_var "POSTGRES_DB")
    ppw=$(get_env_var "POSTGRES_PASSWORD")
    
    # Use defaults if not set
    pu=${pu:-penpot}
    pdb=${pdb:-penpot}
    ppw=${ppw:-penpot}
    
    if [ -z "$pu" ] || [ -z "$pdb" ]; then
        error "POSTGRES_USER and POSTGRES_DB must be set in .env.local"
        return 1
    fi
    
    # Find the PostgreSQL container
    cid=$(/bin/bash -c "$COMPOSE_CMD $COMPOSE_FILES --env-file=$DOCKER_ENV_PATH ps -q penpot-postgres" 2>/dev/null)
    if [ -z "$cid" ]; then
        cid=$(docker ps -q -f "name=^penpot-postgres$" 2>/dev/null | head -1)
    fi
    
    if [ -z "$cid" ]; then
        error "penpot-postgres container not found. Is it running?"
        return 1
    fi
    
    info "Backing up database (pg_dump)..."
    
    if ! docker exec -e PGPASSWORD="$ppw" "$cid" pg_dump -U "$pu" -d "$pdb" -F c -f /tmp/penpot_db.dump; then
        error "pg_dump failed. Check: POSTGRES_USER, POSTGRES_DB, POSTGRES_PASSWORD in .env.local; penpot-postgres running."
        error "Run manually to see the exact error:"
        error "  docker exec -e PGPASSWORD='...' penpot-postgres pg_dump -U $pu -d $pdb -F c -f /tmp/penpot_db.dump"
        return 1
    fi
    
    if ! docker cp "$cid:/tmp/penpot_db.dump" "$backup_dir/penpot_db.dump"; then
        docker exec "$cid" rm -f /tmp/penpot_db.dump 2>/dev/null
        error "Failed to copy dump from container"
        return 1
    fi
    
    docker exec "$cid" rm -f /tmp/penpot_db.dump 2>/dev/null
    
    if gzip -f "$backup_dir/penpot_db.dump" 2>/dev/null; then
        success "Backed up database: penpot_db.dump.gz"
    else
        warning "gzip not available, keeping uncompressed dump"
    fi
}

# Function to backup Docker volume
backup_volume() {
    local backup_dir=$1
    local volume_name=$2
    local backup_filename=$3
    
    info "Backing up volume: $volume_name..."
    
    if ! docker volume inspect "$volume_name" >/dev/null 2>&1; then
        warning "Volume $volume_name not found, skipping..."
        return 0
    fi
    
    if docker run --rm \
        -v "$volume_name:/data:ro" \
        -v "$backup_dir:/backup" \
        ubuntu:22.04 \
        tar czf "/backup/$backup_filename" -C /data .; then
        success "Backed up volume: $backup_filename"
    else
        error "Failed to backup volume: $volume_name"
        return 1
    fi
}

# Main backup function
backup_data() {
    local dt
    dt=$(date +"%Y%m%d-%H%M%S")
    local backup_dir="$BACKUP_DIR/$dt"
    
    mkdir -p "$backup_dir"
    cd "$PROJECT_ROOT" || exit 1
    
    if [ ! -f "$PROJECT_ROOT/docker-compose.production.yml" ]; then
        error "docker-compose.production.yml not found."
        exit 1
    fi
    
    if [ ! -f "$DOCKER_ENV_PATH" ]; then
        error ".env.local not found at $DOCKER_ENV_PATH"
        exit 1
    fi
    
    info "Starting backup to: $backup_dir"
    echo ""
    
    # Backup database
    backup_db_pg_dump "$backup_dir" || exit 1
    
    # Backup assets volume
    backup_volume "$backup_dir" "penpot_assets" "penpot_assets.tar.gz" || exit 1
    
    echo ""
    success "Backup completed: $backup_dir"
    echo ""
    
    # List backup contents
    info "Backup contents:"
    ls -lh "$backup_dir"
    echo ""
}

# Function to check if initial backup is needed
check_initial_backup() {
    if should_run_backup; then
        info "No recent backup found. Running initial backup..."
        backup_data
    else
        info "Recent backup exists, skipping initial backup."
    fi
}

# Main execution
main() {
    local force_backup=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force|-f)
                force_backup=true
                shift
                ;;
            --check-initial)
                check_initial_backup
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                echo "Usage: $0 [--force|-f] [--check-initial]"
                exit 1
                ;;
        esac
    done
    
    if [ "$force_backup" = true ]; then
        backup_data
    else
        if should_run_backup; then
            backup_data
        else
            info "Recent backup exists (within last $BACKUP_RETENTION_DAYS days). Use --force to backup anyway."
            exit 0
        fi
    fi
}

# Run main function
main "$@"
