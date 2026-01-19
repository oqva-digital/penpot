#!/usr/bin/env bash

set -e

EMSDK_QUIET=1 . /opt/emsdk/emsdk_env.sh;

# Only modify UID if it's not 0 (root) and different from current
if [ "${EXTERNAL_UID:-1000}" != "0" ] && [ "${EXTERNAL_UID:-1000}" != "$(id -u penpot 2>/dev/null || echo 1000)" ]; then
    usermod -u ${EXTERNAL_UID:-1000} penpot 2>/dev/null || true;
fi

cp /root/.bashrc /home/penpot/.bashrc
cp /root/.vimrc /home/penpot/.vimrc
cp /root/.tmux.conf /home/penpot/.tmux.conf

chown penpot:users /home/penpot
rsync -ar --chown=penpot:users /opt/cargo/ /home/penpot/.cargo/

export PATH="/home/penpot/.cargo/bin:$PATH"
export CARGO_HOME="/home/penpot/.cargo"

exec "$@"
