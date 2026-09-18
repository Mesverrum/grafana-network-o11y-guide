#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
sed -i 's/\r$//' "${HERE}/build-network-image.sh"
export ALLOY_SRC="${ALLOY_SRC:-/mnt/c/Users/mesve/projects/alloy}"
export ALLOY_IMAGE="${ALLOY_IMAGE:-ghcr.io/mesverrum/alloy-network:v0.1.0}"
bash "${HERE}/build-network-image.sh"
