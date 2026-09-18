#!/usr/bin/env bash
# Login + push ghcr.io/mesverrum/alloy-network. Token on stdin or GHCR_TOKEN.
set -euo pipefail
IMAGE="${ALLOY_IMAGE:-ghcr.io/mesverrum/alloy-network:v0.1.0}"
USER="${GHCR_USER:-Mesverrum}"

if [[ -n "${GHCR_TOKEN:-}" ]]; then
  printf '%s' "${GHCR_TOKEN}" | docker login ghcr.io -u "${USER}" --password-stdin
elif [[ ! -t 0 ]]; then
  docker login ghcr.io -u "${USER}" --password-stdin
else
  echo "ERROR: pipe a token or set GHCR_TOKEN" >&2
  exit 1
fi

docker tag "${IMAGE}" ghcr.io/mesverrum/alloy-network:latest
docker push "${IMAGE}"
docker push ghcr.io/mesverrum/alloy-network:latest
echo "pushed ${IMAGE} and :latest"
echo "If testers cannot pull, set the GHCR package visibility to public."
