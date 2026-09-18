#!/usr/bin/env bash
# Build ghcr.io/mesverrum/alloy-network from Mesverrum/alloy@network-snmp.
# Overlay: compile discovery.snmp + snmp-discovery, copy the snmp-sd library,
# FROM grafana/alloy:latest. Faster than Dockerfile.network-src.
set -euo pipefail

TAG="${ALLOY_IMAGE:-ghcr.io/mesverrum/alloy-network:v0.1.0}"
ALLOY_REF="${ALLOY_REF:-network-snmp}"
GO_IMAGE="${GO_IMAGE:-golang:1.26.6}"

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "==> $*"; }

command -v docker >/dev/null || die "docker required"

resolve_alloy() {
  if [[ -n "${ALLOY_SRC:-}" && -f "${ALLOY_SRC}/internal/component/discovery/snmp/snmp.go" ]]; then
    echo "${ALLOY_SRC}"
    return
  fi
  local c
  for c in \
    "$(cd "$(dirname "$0")/../.." && pwd)/alloy" \
    "/mnt/c/Users/mesve/projects/alloy" \
    "${HOME}/projects/alloy" \
    "${HOME}/alloy"
  do
    if [[ -f "${c}/internal/component/discovery/snmp/snmp.go" ]]; then
      echo "${c}"
      return
    fi
  done
  return 1
}

if ! SRC="$(resolve_alloy)"; then
  SRC="${TMPDIR:-/tmp}/alloy-network-src"
  info "cloning Mesverrum/alloy@${ALLOY_REF} → ${SRC}"
  rm -rf "${SRC}"
  git clone --depth 1 --branch "${ALLOY_REF}" --single-branch \
    https://github.com/Mesverrum/alloy.git "${SRC}"
fi

info "Alloy source: ${SRC}"
[[ -f "${SRC}/go.mod" ]] || die "missing ${SRC}/go.mod"
grep -q 'github.com/Mesverrum/snmp-sd' "${SRC}/go.mod" \
  || die "go.mod missing github.com/Mesverrum/snmp-sd — checkout branch ${ALLOY_REF}"

WORKDIR="${TMPDIR:-/tmp}/alloy-network-image-$$"
mkdir -p "${WORKDIR}"
cleanup() { chmod -R u+w "${WORKDIR}" 2>/dev/null || true; rm -rf "${WORKDIR}" || true; }
trap cleanup EXIT

info "compile with ${GO_IMAGE} (discovery.snmp + snmp-discovery + library)"
docker run --rm \
  -v "${SRC}:/src" \
  -v "${WORKDIR}:/out" \
  -v "${HOME}/.cache/alloy-gomod:/go/pkg/mod" \
  -v "${HOME}/.cache/alloy-gobuild:/root/.cache/go-build" \
  -w /src \
  -e CGO_ENABLED=0 \
  -e GOFLAGS="-buildvcs=false" \
  -e GOPROXY="${GOPROXY:-https://proxy.golang.org,direct}" \
  "${GO_IMAGE}" \
  bash -c '
    set -euo pipefail
    ( cd collector && go build -tags netgo -o /out/alloy . )
    go build -o /out/snmp-discovery github.com/Mesverrum/snmp-sd/cmd/snmp-discovery
    SNMPSD="$(go list -m -f "{{.Dir}}" github.com/Mesverrum/snmp-sd)"
    mkdir -p /out/snmp-lib
    cp -a "${SNMPSD}/snmp/." /out/snmp-lib/
  '

[[ -f "${WORKDIR}/alloy" ]] || die "alloy binary missing"
[[ -f "${WORKDIR}/snmp-discovery" ]] || die "snmp-discovery missing"
[[ -f "${WORKDIR}/snmp-lib/snmp-network.yml" ]] || die "snmp-network.yml missing"
[[ -f "${WORKDIR}/snmp-lib/fingerprinters.yml" ]] || die "fingerprinters.yml missing"

cat >"${WORKDIR}/Dockerfile" <<'EOF'
FROM grafana/alloy:latest
COPY alloy /bin/alloy
COPY snmp-discovery /usr/bin/snmp-discovery
COPY snmp-lib/ /etc/alloy/
EOF

info "docker build ${TAG}"
docker build -t "${TAG}" "${WORKDIR}"
docker image inspect "${TAG}" --format 'ok {{.Id}} {{.Created}}'

info "strings check"
docker run --rm --entrypoint /bin/sh "${TAG}" -c '
  for s in discovery.snmp otelcol.receiver.syslog otelcol.receiver.snmptrap Mesverrum/snmp-sd; do
    n=$(grep -a -o -F "$s" /bin/alloy | wc -l)
    echo "$s $n"
    test "$n" -gt 0
  done
  ls /etc/alloy/snmp-network.yml /etc/alloy/fingerprinters.yml /usr/bin/snmp-discovery
'

info "Built ${TAG}"
echo "Extract onto a poller: see docs/install-alloy.md"
echo "Publish: docker push ${TAG}"
