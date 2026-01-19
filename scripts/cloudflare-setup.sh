#!/usr/bin/env bash
set -euo pipefail

# Script to configure Cloudflare Tunnel

TOKEN="${1:-}"

if [ -z "$TOKEN" ]; then
    echo "Usage: $0 <CLOUDFLARE_TUNNEL_TOKEN>"
    echo ""
    echo "To obtain a token:"
    echo "  1. Visit https://one.dash.cloudflare.com/"
    echo "  2. Go to Zero Trust > Access > Tunnels"
    echo "  3. Create a new tunnel or use an existing one"
    echo "  4. Copy the provided token"
    exit 1
fi

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

# Validate token format (should start with something specific from Cloudflare)
if [ ${#TOKEN} -lt 32 ]; then
    error "Token appears invalid (too short)"
    exit 1
fi

info "Validating Cloudflare token..."

# Test if cloudflared is available
if ! command -v cloudflared &> /dev/null; then
    warning "cloudflared is not installed locally, but will be used via Docker"
fi

# Check if docker-compose.production.yml exists
if [ ! -f "docker-compose.production.yml" ]; then
    error "docker-compose.production.yml not found"
    exit 1
fi

# Check if cloudflared service is already configured
if grep -q "cloudflared:" docker-compose.production.yml; then
    info "cloudflared service already exists in docker-compose.production.yml"
    
    # Update token in .env.local if it exists
    if [ -f ".env.local" ]; then
        if grep -q "^CLOUDFLARE_TUNNEL_TOKEN=" .env.local; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s|^CLOUDFLARE_TUNNEL_TOKEN=.*|CLOUDFLARE_TUNNEL_TOKEN=${TOKEN}|" .env.local
            else
                sed -i "s|^CLOUDFLARE_TUNNEL_TOKEN=.*|CLOUDFLARE_TUNNEL_TOKEN=${TOKEN}|" .env.local
            fi
        else
            echo "CLOUDFLARE_TUNNEL_TOKEN=${TOKEN}" >> .env.local
        fi
        success "Token updated in .env.local"
    else
        warning ".env.local not found. Make sure to add CLOUDFLARE_TUNNEL_TOKEN=${TOKEN}"
    fi
else
    warning "cloudflared service not found in docker-compose.production.yml"
    warning "Make sure docker-compose.production.yml includes the cloudflared service"
fi

info "Cloudflare Tunnel configuration completed"
info ""
info "Next steps:"
echo "  1. Configure the hostname in Cloudflare dashboard:"
echo "     - Visit: https://one.dash.cloudflare.com/"
echo "     - Go to Zero Trust > Access > Tunnels"
echo "     - Select your tunnel"
echo "     - Add a Public Hostname pointing to:"
echo "       - Service: http://penpot-frontend:8080"
echo "       - Path: (leave empty for root)"
echo ""
echo "  2. For WebSocket (required for real-time collaboration):"
echo "     - Add a Public Hostname configuration with:"
echo "       - Service: http://penpot-frontend:8080"
echo "       - Path: /ws/*"
echo "       - Enable WebSocket: Yes"
echo ""
success "Token configured: ${TOKEN:0:20}..."
