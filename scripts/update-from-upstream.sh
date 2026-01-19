#!/usr/bin/env bash
set -euo pipefail

# Script to synchronize with the official Penpot upstream repository

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

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    error "This directory is not a git repository"
    exit 1
fi

# Check if upstream remote exists
if ! git remote | grep -q "^upstream$"; then
    info "Remote 'upstream' not found. Adding..."
    git remote add upstream https://github.com/penpot/penpot.git
    success "Upstream remote added"
fi

# Get current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
info "Current branch: $CURRENT_BRANCH"

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    warning "There are uncommitted changes in the working directory"
    read -p "Continue? Changes may be lost. (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Operation cancelled"
        exit 0
    fi
fi

# Fetch from upstream
info "Fetching updates from upstream..."
git fetch upstream

# Get information about branches
UPSTREAM_MAIN="upstream/main"
LOCAL_MAIN="main"

# Check if main branch exists locally
if ! git show-ref --verify --quiet refs/heads/main; then
    warning "Branch 'main' does not exist locally. Creating..."
    git checkout -b main
fi

# Check if there are new commits in upstream
LOCAL_COMMIT=$(git rev-parse $LOCAL_MAIN 2>/dev/null || echo "")
UPSTREAM_COMMIT=$(git rev-parse $UPSTREAM_MAIN 2>/dev/null || echo "")

if [ "$LOCAL_COMMIT" = "$UPSTREAM_COMMIT" ]; then
    success "Already up to date with upstream"
    exit 0
fi

info "New commits found in upstream"
info "Local:  $LOCAL_COMMIT"
info "Upstream: $UPSTREAM_COMMIT"

# Checkout main branch
if [ "$CURRENT_BRANCH" != "main" ]; then
    info "Checking out main branch..."
    git checkout main
fi

# Merge from upstream
info "Merging upstream/main into main branch..."
if git merge upstream/main --no-ff -m "Merge from upstream main $(date '+%Y-%m-%d %H:%M:%S')"; then
    success "Merge completed successfully"
else
    error "Conflicts detected during merge"
    echo ""
    info "To resolve conflicts:"
    echo "  1. Review conflicted files: git status"
    echo "  2. Resolve conflicts manually"
    echo "  3. Add resolved files: git add <file>"
    echo "  4. Complete the merge: git commit"
    echo ""
    echo "Or cancel the merge: git merge --abort"
    exit 1
fi

# Show statistics
echo ""
info "Merge statistics:"
git log --oneline $LOCAL_COMMIT..HEAD | head -10

echo ""
success "Synchronization with upstream completed!"
info ""
info "Recommended next steps:"
echo "  1. Test the application: ./scripts/setup.sh --skip-build"
echo "  2. If everything is OK, merge into production branch:"
echo "     git checkout production"
echo "     git merge main"
echo "  3. Build and deploy new images:"
echo "     ./scripts/build-images.sh"
echo ""
