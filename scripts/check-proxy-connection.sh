#!/usr/bin/env bash
set -euo pipefail

# Script to check proxy connection to Penpot

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

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

# Check if penpot-frontend is running
info "Checking if penpot-frontend container is running..."
if ! docker ps | grep -q "penpot-frontend"; then
    error "penpot-frontend container is not running"
    echo "Start it with: docker compose -f docker-compose.production.yml up -d"
    exit 1
fi
success "penpot-frontend is running"

# Get penpot-frontend IP
info "Getting penpot-frontend network information..."
PENPOT_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' penpot-frontend 2>/dev/null || echo "")
PENPOT_NETWORK=$(docker inspect -f '{{range $key, $value := .NetworkSettings.Networks}}{{$key}}{{end}}' penpot-frontend 2>/dev/null || echo "")

if [ -n "$PENPOT_IP" ]; then
    info "  IP Address: $PENPOT_IP"
fi
if [ -n "$PENPOT_NETWORK" ]; then
    info "  Network: $PENPOT_NETWORK"
fi

# Check if proxy container exists
info ""
info "Checking for proxy container..."
PROXY_CONTAINER=""
if docker ps -a | grep -q "proxy"; then
    PROXY_CONTAINER=$(docker ps -a | grep "proxy" | awk '{print $NF}' | head -1)
    info "Found proxy container: $PROXY_CONTAINER"
else
    warning "No container with 'proxy' in name found"
    read -p "Enter proxy container name (or press Enter to skip): " PROXY_CONTAINER
fi

if [ -n "$PROXY_CONTAINER" ]; then
    # Check if proxy is on the same network
    info ""
    info "Checking network connectivity..."
    
    PROXY_NETWORKS=$(docker inspect -f '{{range $key, $value := .NetworkSettings.Networks}}{{$key}} {{end}}' "$PROXY_CONTAINER" 2>/dev/null || echo "")
    
    if echo "$PROXY_NETWORKS" | grep -q "$PENPOT_NETWORK"; then
        success "Proxy is on the same network as Penpot ($PENPOT_NETWORK)"
    else
        warning "Proxy is NOT on the same network as Penpot"
        warning "Proxy networks: $PROXY_NETWORKS"
        warning "Penpot network: $PENPOT_NETWORK"
        echo ""
        info "To connect proxy to Penpot network, run:"
        echo "  docker network connect $PENPOT_NETWORK $PROXY_CONTAINER"
    fi
    
    # Test connectivity from proxy to penpot-frontend
    info ""
    info "Testing connectivity from proxy to penpot-frontend..."
    
    if docker exec "$PROXY_CONTAINER" ping -c 2 penpot-frontend &> /dev/null; then
        success "Proxy can ping penpot-frontend by name"
    else
        error "Proxy cannot reach penpot-frontend by name"
        info "Trying with IP address..."
        if [ -n "$PENPOT_IP" ]; then
            if docker exec "$PROXY_CONTAINER" ping -c 2 "$PENPOT_IP" &> /dev/null; then
                warning "Proxy can reach penpot-frontend by IP ($PENPOT_IP) but not by name"
                warning "Use IP address in proxy configuration: http://$PENPOT_IP:8080"
            else
                error "Proxy cannot reach penpot-frontend even by IP"
            fi
        fi
    fi
    
    # Test HTTP connection
    info ""
    info "Testing HTTP connection..."
    if docker exec "$PROXY_CONTAINER" wget -q -O- --timeout=5 http://penpot-frontend:8080 &> /dev/null; then
        success "Proxy can access penpot-frontend via HTTP"
    else
        if [ -n "$PENPOT_IP" ]; then
            if docker exec "$PROXY_CONTAINER" wget -q -O- --timeout=5 "http://$PENPOT_IP:8080" &> /dev/null; then
                warning "Proxy can access penpot-frontend via HTTP using IP"
            else
                error "Proxy cannot access penpot-frontend via HTTP"
            fi
        else
            error "Proxy cannot access penpot-frontend via HTTP"
        fi
    fi
fi

# Summary
echo ""
info "=========================================="
info "Summary"
info "=========================================="
echo ""
info "Penpot Frontend Information:"
echo "  Container Name: penpot-frontend"
echo "  Internal Port: 8080"
if [ -n "$PENPOT_IP" ]; then
    echo "  IP Address: $PENPOT_IP"
fi
if [ -n "$PENPOT_NETWORK" ]; then
    echo "  Network: $PENPOT_NETWORK"
fi
echo ""
info "For Cloudflare Tunnel configuration:"
echo "  Service: http://proxy:80 (if using proxy)"
echo "  Or direct: http://penpot-frontend:8080"
echo ""
info "For Proxy configuration (Caddy/Nginx):"
if [ -n "$PENPOT_IP" ]; then
    echo "  Use: http://penpot-frontend:8080 (preferred)"
    echo "  Or: http://$PENPOT_IP:8080 (if name resolution fails)"
else
    echo "  Use: http://penpot-frontend:8080"
fi
echo ""
