#!/usr/bin/env bash
set -euo pipefail

# Script to build custom Penpot Docker images

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
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

# Function to copy directory (rsync alternative for Windows)
copy_directory() {
    local src="$1"
    local dst="$2"
    
    # Remove destination if it exists
    if [ -d "$dst" ]; then
        rm -rf "$dst"
    fi
    
    # Create destination directory
    mkdir -p "$dst"
    
    # Copy files
    if command -v rsync &> /dev/null; then
        rsync -avr --delete "$src/" "$dst/"
    else
        # Alternative for Windows/Git Bash - use cp -r
        # Note: This preserves permissions and handles most cases
        cp -r "$src"/* "$dst/" 2>/dev/null || {
            # Fallback: copy file by file for better compatibility
            (cd "$src" && find . -type f | while read -r file; do
                mkdir -p "$dst/$(dirname "$file")"
                cp "$file" "$dst/$file"
            done)
        }
    fi
}

# Check if manage.sh exists
if [ ! -f "manage.sh" ]; then
    echo "Error: manage.sh not found. Run this script from the project root."
    exit 1
fi

# Get version from git or use "latest"
VERSION=$(git describe --tags --match "*.*.*" 2>/dev/null || echo "latest")
info "Version detected: $VERSION"

# Check if bundles already exist
BUILD_BUNDLES=true
if [ -d "bundles/frontend" ] && [ -d "bundles/backend" ] && [ -d "bundles/exporter" ]; then
    read -p "Bundles already exist. Rebuild? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        BUILD_BUNDLES=false
        info "Using existing bundles"
    fi
fi

# Fix permissions for build directories (needed when running as root)
fix_build_permissions() {
    info "Fixing permissions for build directories..."
    # Make directories writable by group (for UID 1000 in container)
    find frontend backend exporter -type d -name "node_modules" -o -name "target" -o -name ".shadow-cljs" 2>/dev/null | while read -r dir; do
        if [ -d "$dir" ]; then
            chmod -R u+w,g+w "$dir" 2>/dev/null || true
        fi
    done
    # Pre-create and fix permissions for directories that will be created during build
    mkdir -p frontend/node_modules backend/target exporter/target frontend/target 2>/dev/null || true
    chmod -R 775 frontend/node_modules backend/target exporter/target frontend/target 2>/dev/null || true
    # Fix ownership if running as root (make it accessible to UID 1000)
    if [ "$(id -u)" = "0" ]; then
        # Use chmod to make writable by all, or chown to a group that UID 1000 can access
        chmod -R 777 frontend/node_modules backend/target exporter/target frontend/target 2>/dev/null || true
    fi
}

# Build bundles
if [ "$BUILD_BUNDLES" = "true" ]; then
    fix_build_permissions
    info "Building bundles..."
    
    info "Building frontend bundle..."
    ./manage.sh build-frontend-bundle
    
    info "Building backend bundle..."
    ./manage.sh build-backend-bundle
    
    info "Building exporter bundle..."
    ./manage.sh build-exporter-bundle
    
    success "Bundles built successfully"
fi

# Build Docker images
info "Building Docker images..."

# Frontend
info "Building frontend image..."
copy_directory ./bundles/frontend ./docker/images/bundle-frontend
pushd ./docker/images
docker build \
    -t penpotapp/frontend:$VERSION \
    -t penpotapp/frontend:latest \
    --build-arg BUNDLE_PATH="./bundle-frontend/" \
    -f Dockerfile.frontend .
popd
success "Frontend image built"

# Backend
info "Building backend image..."
copy_directory ./bundles/backend ./docker/images/bundle-backend
pushd ./docker/images
docker build \
    -t penpotapp/backend:$VERSION \
    -t penpotapp/backend:latest \
    --build-arg BUNDLE_PATH="./bundle-backend/" \
    -f Dockerfile.backend .
popd
success "Backend image built"

# Exporter
info "Building exporter image..."
copy_directory ./bundles/exporter ./docker/images/bundle-exporter
pushd ./docker/images
docker build \
    -t penpotapp/exporter:$VERSION \
    -t penpotapp/exporter:latest \
    --build-arg BUNDLE_PATH="./bundle-exporter/" \
    -f Dockerfile.exporter .
popd
success "Exporter image built"

echo ""
success "All images built successfully!"
info "Available images:"
echo "  - penpotapp/frontend:$VERSION"
echo "  - penpotapp/backend:$VERSION"
echo "  - penpotapp/exporter:$VERSION"
echo ""

# Ask if want to push (if registry configured)
if [ -n "${DOCKER_REGISTRY:-}" ]; then
    read -p "Push images to registry? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "Pushing images..."
        docker push penpotapp/frontend:$VERSION
        docker push penpotapp/frontend:latest
        docker push penpotapp/backend:$VERSION
        docker push penpotapp/backend:latest
        docker push penpotapp/exporter:$VERSION
        docker push penpotapp/exporter:latest
        success "Push completed"
    fi
fi
