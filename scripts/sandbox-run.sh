#!/usr/bin/env bash
# Run model-authored code/tests in a stripped sandbox: NO network, read-only outside the workdir.
# Prefers a container (docker/podman); falls back to env -i + timeout (weaker — logs a WARN).
# Note: the fallback needs `timeout` (coreutils; present on Linux + macOS 13+).
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "${DIR}/lib/common.sh"
[ "$#" -ge 1 ] || die "usage: sandbox-run.sh <cmd> [args...]"
WORK="${CCLL_SANDBOX_WORK:-$PWD}"; TIMEOUT="${CCLL_SANDBOX_TIMEOUT:-120}"
IMG="${CCLL_SANDBOX_IMAGE:-cc-local-loop-runner}"; RT="${CCLL_SANDBOX_RUNTIME:-auto}"
if { [ "$RT" = auto ] || [ "$RT" = docker ]; } && command -v docker >/dev/null 2>&1; then
  exec docker run --rm --network none --read-only --tmpfs /tmp -v "${WORK}:/work:rw" -w /work "$IMG" timeout "$TIMEOUT" "$@"
elif { [ "$RT" = auto ] || [ "$RT" = podman ]; } && command -v podman >/dev/null 2>&1; then
  exec podman run --rm --network none --read-only --tmpfs /tmp -v "${WORK}:/work:rw" -w /work "$IMG" timeout "$TIMEOUT" "$@"
else
  log "WARN: no container runtime — running with env -i + timeout only (NO network/fs isolation). Build a runner image for real isolation."
  exec env -i PATH=/usr/bin:/bin HOME=/tmp timeout "$TIMEOUT" "$@"
fi
