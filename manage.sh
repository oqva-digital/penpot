#!/usr/bin/env bash

export ORGANIZATION="penpotapp";
export DEVENV_IMGNAME="$ORGANIZATION/devenv";
export DEVENV_PNAME="penpotdev";

# Get current user ID, but use 1000 if root (UID 0) to avoid conflicts in containers
CURRENT_USER_ID_RAW=$(id -u);
if [ "$CURRENT_USER_ID_RAW" = "0" ]; then
    export CURRENT_USER_ID=1000;
else
    export CURRENT_USER_ID=$CURRENT_USER_ID_RAW;
fi
export CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD);

export IMAGEMAGICK_VERSION=7.1.2-0

# Safe directory to avoid ownership errors with Git
git config --global --add safe.directory /home/penpot/penpot || true

# Set default java options
export JAVA_OPTS=${JAVA_OPTS:-"-Xmx1000m -Xms50m"};

set -e

ARCH=$(uname -m)

# Function to convert path for Docker on Windows
# On Windows (Git Bash/WSL), Docker needs Windows-style paths
get_docker_path() {
    local path="$1"
    
    # Try cygpath first (available in Git Bash and Cygwin) - this is the most reliable
    if command -v cygpath &> /dev/null; then
        local win_path=$(cygpath -w "$path" 2>/dev/null)
        if [ -n "$win_path" ]; then
            echo "$win_path"
            return
        fi
    fi
    
    # Git Bash/MSYS on Windows - convert /c/... to C:\...
    # Check for Windows environment
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]] || \
       [[ -n "$MSYSTEM" && ("$MSYSTEM" == "MINGW64" || "$MSYSTEM" == "MINGW32") ]] || \
       [[ "$(uname -s)" =~ MINGW ]]; then
        if [[ "$path" =~ ^/([a-zA-Z])/ ]]; then
            local drive="${BASH_REMATCH[1]}"
            local rest="${path#/${drive}/}"
            # Convert forward slashes to backslashes for Windows
            rest="${rest//\//\\}"
            echo "${drive}:\\${rest}"
            return
        fi
    fi
    
    # WSL - convert /mnt/c/... to //c/... (Docker Desktop format)
    if [[ -n "$WSL_DISTRO_NAME" ]] || ([[ -f /proc/version ]] && grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null); then
        if [[ "$path" =~ ^/mnt/([a-zA-Z])/ ]]; then
            local drive="${BASH_REMATCH[1]}"
            local rest="${path#/mnt/${drive}/}"
            echo "//${drive}/${rest}"
            return
        fi
    fi
    
    # Linux/macOS - use as is
    echo "$path"
}

if [[ "$ARCH" == "x86_64" || "$ARCH" == "amd64" || "$ARCH" == "i386" || "$ARCH" == "i686" ]]; then
    ARCH="amd64"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    ARCH="arm64"
else
    echo "Unknown architecture $ARCH"
    exit -1
fi


function print-current-version {
    echo -n "$(git describe --tags --match "*.*.*")";
}

function setup-buildx {
    docker run --privileged --rm tonistiigi/binfmt --install all
    docker buildx inspect penpot > /dev/null 2>&1;

    if [ $? -eq 1 ]; then
        docker buildx create --name=penpot --use
        docker buildx inspect --bootstrap > /dev/null 2>&1;
    else
        docker buildx use penpot;
        docker buildx inspect --bootstrap  > /dev/null 2>&1;
    fi
}

function build-devenv {
    set +e;

    pushd docker/devenv;

    if [ "$1" = "--local" ]; then
        echo "Build local only $DEVENV_IMGNAME:latest image";
        docker build -t $DEVENV_IMGNAME:latest .;
    else
        echo "Build and push $DEVENV_IMGNAME:latest image";
        setup-buildx;

        docker buildx build \
          --platform linux/amd64,linux/arm64 \
          --output type=registry \
          -t $DEVENV_IMGNAME:latest .;

        docker pull $DEVENV_IMGNAME:latest;
    fi

    popd;
}

function pull-devenv {
    set -ex
    docker pull $DEVENV_IMGNAME:latest
}

function pull-devenv-if-not-exists {
    if [[ ! $(docker images $DEVENV_IMGNAME:latest -q) ]]; then
        pull-devenv $@
    fi
}

function start-devenv {
    pull-devenv-if-not-exists $@;

    docker compose -p $DEVENV_PNAME -f docker/devenv/docker-compose.yaml up -d;
}

function create-devenv {
    pull-devenv-if-not-exists $@;

    docker compose -p $DEVENV_PNAME -f docker/devenv/docker-compose.yaml create;
}

function stop-devenv {
    docker compose -p $DEVENV_PNAME -f docker/devenv/docker-compose.yaml stop -t 2;
}

function drop-devenv {
    docker compose -p $DEVENV_PNAME -f docker/devenv/docker-compose.yaml down -t 2 -v;

    echo "Clean old development image $DEVENV_IMGNAME..."
    docker images $DEVENV_IMGNAME -q | awk '{print $3}' | xargs --no-run-if-empty docker rmi
}

function log-devenv {
    docker compose -p $DEVENV_PNAME -f docker/devenv/docker-compose.yaml logs -f --tail=50
}

function run-devenv-tmux {
    if [[ ! $(docker ps -f "name=penpot-devenv-main" -q) ]]; then
        start-devenv
        echo "Waiting for containers fully start (5s)..."
        sleep 5;
    fi

    docker exec -ti penpot-devenv-main sudo -EH -u penpot PENPOT_PLUGIN_DEV=$PENPOT_PLUGIN_DEV /home/start-tmux.sh
}

function run-devenv-shell {
    if [[ ! $(docker ps -f "name=penpot-devenv-main" -q) ]]; then
        start-devenv
    fi
    docker exec -ti \
           -e JAVA_OPTS="$JAVA_OPTS" \
           -e EXTERNAL_UID=$CURRENT_USER_ID \
           penpot-devenv-main sudo -EH -u penpot bash;
}

function run-devenv-isolated-shell {
    docker volume create ${DEVENV_PNAME}_user_data;
    
    # Get current directory and convert for Docker on Windows if needed
    local current_dir=$(pwd)
    local docker_path=$(get_docker_path "$current_dir")
    
    # Use -v syntax for volumes on Windows for better compatibility
    local volume_name="${DEVENV_PNAME}_user_data"
    docker run -ti --rm \
           -v "${volume_name}:/home/penpot" \
           --mount "type=bind,source=$docker_path,target=/home/penpot/penpot" \
           -e EXTERNAL_UID=$CURRENT_USER_ID \
           -e BUILD_STORYBOOK=$BUILD_STORYBOOK \
           -e BUILD_WASM=$BUILD_WASM \
           -e SHADOWCLJS_EXTRA_PARAMS=$SHADOWCLJS_EXTRA_PARAMS \
           -e JAVA_OPTS="$JAVA_OPTS" \
           $DEVENV_IMGNAME:latest sh -c "cd /home/penpot/penpot/$1 && sudo -EH -u penpot bash"
}

function build-imagemagick-docker-image {
    set +e;
    echo "Building image penpotapp/imagemagick:$IMAGEMAGICK_VERSION"

    pushd docker/imagemagick;

    output_option="type=registry";
    platform="linux/amd64,linux/arm64";

    if [ "$1" = "--local" ]; then
        output_option="type=docker";
        platform="linux/$ARCH"
    fi

    setup-buildx;

    docker buildx build \
      --build-arg IMAGEMAGICK_VERSION=$IMAGEMAGICK_VERSION \
      --platform $platform \
      --output $output_option \
      -t penpotapp/imagemagick:latest \
      -t penpotapp/imagemagick:$IMAGEMAGICK_VERSION .;

    popd;
}

function build {
    echo ">> build start: $1"
    local version=$(print-current-version);
    local script=${2:-build}

    pull-devenv-if-not-exists;
    docker volume create ${DEVENV_PNAME}_user_data;
    
    # Get current directory and convert for Docker on Windows if needed
    local current_dir=$(pwd)
    local docker_path=$(get_docker_path "$current_dir")
    
    # On Windows, verify the path is accessible to Docker
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]] || [[ -n "$MSYSTEM" ]]; then
        if [[ ! "$docker_path" =~ ^[A-Z]:\\ ]]; then
            echo "Warning: Path conversion may have failed. Original: $current_dir, Converted: $docker_path"
            echo "On Windows, ensure Docker Desktop has access to the drive containing your project."
            echo "Check Docker Desktop Settings > Resources > File Sharing"
        fi
    fi
    
    # Use sh -c with cd to avoid Windows path interpretation issues with -w/--workdir
    # Use -v syntax for volumes on Windows for better compatibility
    local volume_name="${DEVENV_PNAME}_user_data"
    
    # If running as root on host, fix permissions before build and use root in container
    # This avoids permission issues when mounting host directories
    local docker_user=""
    if [ "$(id -u)" = "0" ]; then
        # Running as root: fix permissions on host and run as root in container
        # Fix permissions for directories that will be written during build
        chmod -R 777 "$docker_path/$1/node_modules" "$docker_path/$1/target" 2>/dev/null || true
        mkdir -p "$docker_path/$1/node_modules" "$docker_path/$1/target" 2>/dev/null || true
        chmod -R 777 "$docker_path/$1/node_modules" "$docker_path/$1/target" 2>/dev/null || true
        # Run as root in container to avoid permission issues
        docker run -t --rm \
               -v "${volume_name}:/home/penpot" \
               --mount "type=bind,source=$docker_path,target=/home/penpot/penpot" \
               -e BUILD_STORYBOOK=$BUILD_STORYBOOK \
               -e BUILD_WASM=$BUILD_WASM \
               -e SHADOWCLJS_EXTRA_PARAMS=$SHADOWCLJS_EXTRA_PARAMS \
               -e JAVA_OPTS="$JAVA_OPTS" \
               --user root \
               $DEVENV_IMGNAME:latest sh -c "cd /home/penpot/penpot/$1 && ./scripts/$script $version"
    else
        # Running as regular user: use normal flow
        docker run -t --rm \
               -v "${volume_name}:/home/penpot" \
               --mount "type=bind,source=$docker_path,target=/home/penpot/penpot" \
               -e EXTERNAL_UID=$CURRENT_USER_ID \
               -e BUILD_STORYBOOK=$BUILD_STORYBOOK \
               -e BUILD_WASM=$BUILD_WASM \
               -e SHADOWCLJS_EXTRA_PARAMS=$SHADOWCLJS_EXTRA_PARAMS \
               -e JAVA_OPTS="$JAVA_OPTS" \
               $DEVENV_IMGNAME:latest sh -c "cd /home/penpot/penpot/$1 && sudo -EH -u penpot ./scripts/$script $version"
    fi

    echo ">> build end: $1"
}

function put-license-file {
    local target=$1;
    tee -a $target/LICENSE  >> /dev/null <<EOF
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

Copyright (c) KALEIDOS INC
EOF
}

function build-frontend-bundle {
    echo ">> bundle frontend start";

    mkdir -p ./bundles
    local version=$(print-current-version);
    local bundle_dir="./bundles/frontend";

    build "frontend";

    rm -rf $bundle_dir;
    mv ./frontend/target/dist $bundle_dir;
    echo $version > $bundle_dir/version.txt;
    put-license-file $bundle_dir;
    echo ">> bundle frontend end";
}

function build-backend-bundle {
    echo ">> bundle backend start";

    mkdir -p ./bundles
    local version=$(print-current-version);
    local bundle_dir="./bundles/backend";

    build "backend";

    rm -rf $bundle_dir;
    mv ./backend/target/dist $bundle_dir;
    echo $version > $bundle_dir/version.txt;
    put-license-file $bundle_dir;
    echo ">> bundle backend end";
}

function build-exporter-bundle {
    echo ">> bundle exporter start";

    mkdir -p ./bundles
    local version=$(print-current-version);
    local bundle_dir="./bundles/exporter";

    build "exporter";

    rm -rf $bundle_dir;
    mv ./exporter/target $bundle_dir;
    echo $version > $bundle_dir/version.txt
    put-license-file $bundle_dir;
    echo ">> bundle exporter end";
}

function build-storybook-bundle {
    echo ">> bundle storybook start";

    mkdir -p ./bundles
    local version=$(print-current-version);
    local bundle_dir="./bundles/storybook";

    build "frontend" "build-storybook";

    rm -rf $bundle_dir;
    mv ./frontend/storybook-static $bundle_dir;
    echo $version > $bundle_dir/version.txt;
    put-license-file $bundle_dir;
    echo ">> bundle storybook end";
}

function build-docs-bundle {
    echo ">> bundle docs start";

    mkdir -p ./bundles
    local version=$(print-current-version);
    local bundle_dir="./bundles/docs";

    build "docs";

    rm -rf $bundle_dir;
    mv ./docs/_dist $bundle_dir;
    echo $version > $bundle_dir/version.txt;
    put-license-file $bundle_dir;
    echo ">> bundle docs end";
}

function build-frontend-docker-image {
    rsync -avr --delete ./bundles/frontend/ ./docker/images/bundle-frontend/;
    pushd ./docker/images;
    docker build \
        -t penpotapp/frontend:$CURRENT_BRANCH -t penpotapp/frontend:latest \
        --build-arg BUNDLE_PATH="./bundle-frontend/" \
        -f Dockerfile.frontend .;
    popd;
}

function build-backend-docker-image {
    rsync -avr --delete ./bundles/backend/ ./docker/images/bundle-backend/;
    pushd ./docker/images;
    docker build \
        -t penpotapp/backend:$CURRENT_BRANCH -t penpotapp/backend:latest \
        --build-arg BUNDLE_PATH="./bundle-backend/" \
        -f Dockerfile.backend .;
    popd;
}

function build-exporter-docker-image {
    rsync -avr --delete ./bundles/exporter/ ./docker/images/bundle-exporter/;
    pushd ./docker/images;
    docker build \
        -t penpotapp/exporter:$CURRENT_BRANCH -t penpotapp/exporter:latest \
        --build-arg BUNDLE_PATH="./bundle-exporter/" \
        -f Dockerfile.exporter .;
    popd;
}

function build-storybook-docker-image {
    rsync -avr --delete ./bundles/storybook/ ./docker/images/bundle-storybook/;
    pushd ./docker/images;
    docker build \
        -t penpotapp/storybook:$CURRENT_BRANCH -t penpotapp/storybook:latest \
        --build-arg BUNDLE_PATH="./bundle-storybook/" \
        -f Dockerfile.storybook .;
    popd;
}

function usage {
    echo "PENPOT build & release manager"
    echo "USAGE: $0 OPTION"
    echo "Options:"
    echo "- pull-devenv                      Pulls docker development oriented image"
    echo "- build-devenv                     Build docker development oriented image"
    echo "- build-devenv --local             Build a local docker development oriented image"
    echo "- create-devenv                    Create the development oriented docker compose service."
    echo "- start-devenv                     Start the development oriented docker compose service."
    echo "- stop-devenv                      Stops the development oriented docker compose service."
    echo "- drop-devenv                      Remove the development oriented docker compose containers, volumes and clean images."
    echo "- run-devenv                       Attaches to the running devenv container and starts development environment"
    echo "- run-devenv-shell                 Attaches to the running devenv container and starts a bash shell."
    echo "- isolated-shell                   Starts a bash shell in a new devenv container."
    echo "- log-devenv                       Show logs of the running devenv docker compose service."
    echo ""
    echo "- build-bundle                     Build all bundles (frontend, backend and exporter)."
    echo "- build-frontend-bundle            Build frontend bundle"
    echo "- build-backend-bundle             Build backend bundle."
    echo "- build-exporter-bundle            Build exporter bundle."
    echo "- build-storybook-bundle           Build storybook bundle."
    echo "- build-docs-bundle                Build docs bundle."
    echo ""
    echo "- build-docker-images              Build all docker images (frontend, backend and exporter)."
    echo "- build-frontend-docker-image      Build frontend docker images."
    echo "- build-backend-docker-image       Build backend docker images."
    echo "- build-exporter-docker-image      Build exporter docker images."
    echo "- build-storybook-docker-image     Build storybook docker images."
    echo ""
    echo "- version                          Show penpot's version."
}

case $1 in
    version)
        print-current-version
        ;;

    ## devenv related commands
    pull-devenv)
        pull-devenv ${@:2};
        ;;

    build-devenv)
        shift;
        build-devenv $@;
        ;;

    create-devenv)
        create-devenv ${@:2}
        ;;

    start-devenv)
        start-devenv ${@:2}
        ;;
    run-devenv)
        run-devenv-tmux ${@:2}
        ;;
    run-devenv-shell)
        run-devenv-shell ${@:2}
        ;;

    isolated-shell)
        run-devenv-isolated-shell ${@:2}
        ;;

    stop-devenv)
        stop-devenv ${@:2}
        ;;
    drop-devenv)
        drop-devenv ${@:2}
        ;;
    log-devenv)
        log-devenv ${@:2}
        ;;

    ## production builds
    build-bundle)
        build-frontend-bundle;
        build-backend-bundle;
        build-exporter-bundle;
        build-storybook-bundle;
        ;;

    build-frontend-bundle)
        build-frontend-bundle;
        ;;

    build-backend-bundle)
        build-backend-bundle;
        ;;

    build-exporter-bundle)
        build-exporter-bundle;
        ;;
    
    build-storybook-bundle)
        build-storybook-bundle;
        ;;

    build-docs-bundle)
        build-docs-bundle;
        ;;

    build-imagemagick-docker-image)
        shift;
        build-imagemagick-docker-image $@;
        ;;

    build-docker-images)
        build-frontend-docker-image
        build-backend-docker-image
        build-exporter-docker-image
        build-storybook-docker-image
        ;;

    build-frontend-docker-image)
        build-frontend-docker-image
        ;;

    build-backend-docker-image)
        build-backend-docker-image
        ;;

    build-exporter-docker-image)
        build-exporter-docker-image
        ;;
 
    build-storybook-docker-image)
        build-storybook-docker-image
        ;;

    *)
        usage
        ;;
esac
