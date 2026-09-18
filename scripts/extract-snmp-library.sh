#!/usr/bin/env bash
# Copy the image's fingerprinters + module catalog onto the host so you can
# edit them without rebuilding Alloy. Then:
#   cp compose.override.example.yaml compose.override.yaml
#   docker compose up -d --force-recreate
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${ALLOY_IMAGE:-ghcr.io/mesverrum/alloy-network:v0.1.0}"
OUT="${HERE}/alloy/library"
NAME="alloy-lib-extract-$$"

mkdir -p "${OUT}"
docker pull "${IMAGE}"
docker create --name "${NAME}" "${IMAGE}" >/dev/null
trap 'docker rm -f "${NAME}" >/dev/null 2>&1 || true' EXIT
docker cp "${NAME}:/etc/alloy/fingerprinters.yml" "${OUT}/fingerprinters.yml"
docker cp "${NAME}:/etc/alloy/snmp-network.yml" "${OUT}/snmp-network.yml"
echo "wrote ${OUT}/fingerprinters.yml"
echo "wrote ${OUT}/snmp-network.yml"
echo "Keep these two from the same extract. Then:"
echo "  cp compose.override.example.yaml compose.override.yaml"
echo "  # edit alloy/library/…  (module= names must exist in snmp-network.yml)"
echo "  docker compose up -d --force-recreate"
