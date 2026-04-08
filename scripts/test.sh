#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SMOKE_DIR="${ROOT_DIR}/tests/agents/smoke/"
IMAGE_REF=""
AGENT=""

usage() {
  cat <<'USAGE'
Usage: scripts/test.sh --image <image-ref> --agent <agent> [bats-args...]

Options:
  --image <ref>   Image reference to test (required)
  --agent <agent> Agent name for smoke tests (required)
  -h, --help      Show this help and exit

Examples:
  scripts/test.sh --image example/aicage:codex-ubuntu --agent codex
USAGE
  exit 1
}

# shellcheck source=../scripts/common.sh
source "${ROOT_DIR}/scripts/common.sh"

log() {
  printf '[test] %s\n' "$*" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)
      [[ $# -ge 2 ]] || usage
      IMAGE_REF="$2"
      shift 2
      ;;
    --agent)
      [[ $# -ge 2 ]] || usage
      AGENT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

[[ -n "${IMAGE_REF}" ]] || { log "--image is required"; usage; }
[[ -n "${AGENT}" ]] || { log "--agent is required"; usage; }

log "Running smoke tests via bats"
AICAGE_IMAGE="${IMAGE_REF}" AGENT="${AGENT}" bats "${SMOKE_DIR}" "$@"
