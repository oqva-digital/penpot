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

# Function to detect operating system
detect_os() {
    local os=$(uname -s)
    local arch=$(uname -m)
    
    case "$os" in
        Linux|MINGW*|MSYS*|CYGWIN*)
            OS_TYPE="linux"
            ;;
        Darwin)
            OS_TYPE="macos"
            ;;
        *)
            error "Unsupported operating system: $os"
            exit 1
            ;;
    esac
    
    case "$arch" in
        x86_64|amd64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        *)
            error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
    
    info "System detected: $OS_TYPE ($ARCH)"
}

# Function to check prerequisites
check_prerequisites() {
    info "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker --version &> /dev/null; then
        error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        error "Docker Compose is not available. Please install Docker Compose."
        exit 1
    fi
    
    # Check Python (for key generation)
    if ! command -v python3 &> /dev/null; then
        error "Python 3 is not installed. Required for generating secret keys."
        exit 1
    fi
    
    success "All prerequisites are installed"
}

# Function to generate .env.local if it doesn't exist
setup_env() {
    if [ -f ".env.local" ]; then
        warning ".env.local already exists. Using existing configuration."
        return
    fi
    
    info "Creating .env.local from template..."
    
    if [ ! -f "env.example" ]; then
        error "env.example not found. Please run the secrets generation script first."
        exit 1
    fi
    
    cp env.example .env.local
    
    # Generate secrets
    info "Generating keys and passwords..."
    "$SCRIPT_DIR/generate-secrets.sh" .env.local
    
    success ".env.local created successfully"
}

# Function to safely get a variable value from .env.local
get_env_var() {
    local var_name="$1"
    if [ -f ".env.local" ]; then
        # Extract the variable value, handling quoted and unquoted values
        # This safely extracts the value without executing it as a command
        grep "^${var_name}=" .env.local 2>/dev/null | sed "s/^${var_name}=//" | sed 's/^["'\'']//; s/["'\'']$//' | head -1
    fi
}

# Function to configure Cloudflare Tunnel
setup_cloudflare() {
    info "Configuring Cloudflare Tunnel..."
    
    if [ ! -f ".env.local" ]; then
        error ".env.local not found"
        exit 1
    fi
    
    # Get CLOUDFLARE_TUNNEL_TOKEN safely from .env.local
    CLOUDFLARE_TUNNEL_TOKEN=$(get_env_var "CLOUDFLARE_TUNNEL_TOKEN")
    
    if [ -z "$CLOUDFLARE_TUNNEL_TOKEN" ]; then
        warning "CLOUDFLARE_TUNNEL_TOKEN not configured. Cloudflare Tunnel will not be started."
        warning "Configure the token in .env.local to enable the tunnel."
        return
    fi
    
    "$SCRIPT_DIR/cloudflare-setup.sh" "$CLOUDFLARE_TUNNEL_TOKEN"
    
    success "Cloudflare Tunnel configured"
}

# Function to build images
build_images() {
    local skip_build="${1:-false}"
    
    if [ "$skip_build" = "true" ]; then
        info "Skipping image build (using existing images)"
        return
    fi
    
    info "Building custom Docker images..."
    
    # Check if images already exist
    if docker images | grep -q "penpotapp/frontend.*latest" && \
       docker images | grep -q "penpotapp/backend.*latest" && \
       docker images | grep -q "penpotapp/exporter.*latest"; then
        read -p "Images already exist. Rebuild? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Using existing images"
            return
        fi
    fi
    
    "$SCRIPT_DIR/build-images.sh"
    
    success "Images built successfully"
}

# Function to start services
start_services() {
    info "Starting Docker services..."
    
    if [ ! -f "docker-compose.production.yml" ]; then
        error "docker-compose.production.yml not found"
        exit 1
    fi
    
    # Check if already running
    if docker compose -f docker-compose.production.yml ps | grep -q "Up"; then
        warning "Services are already running. Restart? (y/N)"
        read -p "" -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            info "Stopping existing services..."
            docker compose -f docker-compose.production.yml down
        else
            info "Keeping existing services"
            return
        fi
    fi
    
    # Start services
    docker compose -f docker-compose.production.yml --env-file .env.local up -d
    
    info "Waiting for services to start..."
    sleep 10
    
    # Validate services
    validate_services
    
    success "Services started successfully"
}

# Function to validate services
validate_services() {
    info "Validating services..."
    
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        local healthy=true
        
        # Check PostgreSQL
        if ! docker compose -f docker-compose.production.yml exec -T penpot-postgres pg_isready -U penpot &> /dev/null; then
            healthy=false
        fi
        
        # Check Valkey
        if ! docker compose -f docker-compose.production.yml exec -T penpot-valkey valkey-cli ping | grep -q "PONG"; then
            healthy=false
        fi
        
        # Check Backend (port 6060)
        if ! docker compose -f docker-compose.production.yml exec -T penpot-backend curl -f http://localhost:6060/api/health &> /dev/null; then
            healthy=false
        fi
        
        if [ "$healthy" = "true" ]; then
            success "All services are healthy"
            return
        fi
        
        attempt=$((attempt + 1))
        sleep 2
    done
    
    warning "Some services may not be fully ready. Check logs with: docker compose -f docker-compose.production.yml logs"
}

# Function to display final information
show_summary() {
    echo ""
    echo "=========================================="
    success "Setup completed successfully!"
    echo "=========================================="
    echo ""
    
    # Get variables from .env.local safely
    PENPOT_PUBLIC_URI=$(get_env_var "PENPOT_PUBLIC_URI")
    PENPOT_VERSION=$(get_env_var "PENPOT_VERSION")
    
    info "Environment information:"
    echo "  - Public URL: ${PENPOT_PUBLIC_URI:-not configured}"
    echo "  - Version: ${PENPOT_VERSION:-latest}"
    echo ""
    
    info "Service status:"
    docker compose -f docker-compose.production.yml ps
    echo ""
    
    info "Useful commands:"
    echo "  - View logs: docker compose -f docker-compose.production.yml logs -f"
    echo "  - Stop services: docker compose -f docker-compose.production.yml down"
    echo "  - Restart services: docker compose -f docker-compose.production.yml restart"
    echo "  - View status: docker compose -f docker-compose.production.yml ps"
    echo ""
    
    if [ -f ".env.local" ]; then
        warning "Generated credentials have been saved to .env.local"
        warning "Keep this file secure and do not share it!"
    fi
    
    info "Next steps:"
    echo "  1. Access the application at: ${PENPOT_PUBLIC_URI:-http://localhost:9001}"
    echo "  2. Create an administrator account"
    echo "  3. Configure SMTP for email sending (if needed)"
    echo "  4. Review configurations in .env.local"
    echo ""
}

# Main function
main() {
    echo ""
    info "=========================================="
    info "Automated Penpot Self-Hosted Setup"
    info "=========================================="
    echo ""
    
    # Parse arguments
    SKIP_BUILD=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-build)
                SKIP_BUILD=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [--skip-build]"
                echo ""
                echo "Options:"
                echo "  --skip-build    Skip Docker image build"
                echo "  --help, -h      Show this help message"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                echo "Use --help to see available options"
                exit 1
                ;;
        esac
    done
    
    # Execute steps
    detect_os
    check_prerequisites
    setup_env
    setup_cloudflare
    build_images "$SKIP_BUILD"
    start_services
    show_summary
}

# Execute main function
main "$@"
