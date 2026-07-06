#!/usr/bin/env bash
# Run model-authored code/tests in a stripped sandbox: NO network, read-only outside the workdir.
# Prefers a container (docker/podman); falls back to env -i + timeout (weaker — logs a WARN).
# Portability: a docker/podman *binary* can be present while the daemon is down, and stock macOS
# ships NO `timeout` (brew's coreutils installs `gtimeout`). So we (a) probe daemon liveness before
# committing via exec, and (b) resolve timeout/gtimeout, degrading to no-timeout-wall (loud WARN)
# rather than dying, so the fallback stays functional everywhere.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "${DIR}/lib/common.sh"
[ "$#" -ge 1 ] || die "usage: sandbox-run.sh <cmd> [args...]"
WORK="${CCLL_SANDBOX_WORK:-$PWD}"; TIMEOUT="${CCLL_SANDBOX_TIMEOUT:-120}"
IMG="${CCLL_SANDBOX_IMAGE:-cc-local-loop-runner}"; RT="${CCLL_SANDBOX_RUNTIME:-auto}"
if { [ "$RT" = auto ] || [ "$RT" = docker ]; } && command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  exec docker run --rm --network none --read-only --tmpfs /tmp -v "${WORK}:/work:rw" -w /work "$IMG" timeout "$TIMEOUT" "$@"
elif { [ "$RT" = auto ] || [ "$RT" = podman ]; } && command -v podman >/dev/null 2>&1 && podman info >/dev/null 2>&1; then
  exec podman run --rm --network none --read-only --tmpfs /tmp -v "${WORK}:/work:rw" -w /work "$IMG" timeout "$TIMEOUT" "$@"
else
  log "WARN: no live container runtime — running with env -i + timeout only (NO network/fs isolation). Build a runner image for real isolation."
  # `env -i` wipes PATH, so pass the timeout binary's own dir in PATH and invoke it by name.
  TO="$(command -v timeout || command -v gtimeout || true)"
  if [ -n "$TO" ]; then
    TO_NAME="$(basename "$TO")"; TO_DIR="$(dirname "$TO")"
    exec env -i "PATH=${TO_DIR}:/usr/bin:/bin" HOME=/tmp "$TO_NAME" "$TIMEOUT" "$@"
  else
    log "WARN: no 'timeout'/'gtimeout' on host — running WITHOUT a timeout wall."
    exec env -i PATH=/usr/bin:/bin HOME=/tmp "$@"
  fi
fi
