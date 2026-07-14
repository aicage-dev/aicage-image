#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

die() {
  echo "[build-all] $*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage: scripts/debug/build-all.sh [build-options]

Builds the full matrix of <agent>-<base> combinations. Any options after the script name are
forwarded to scripts/debug/build.sh for each build.

Options:
  -h, --help          Show this help and exit
USAGE
  exit 1
}

# shellcheck source=./scripts/common.sh
source "${ROOT_DIR}/scripts/common.sh"

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  usage
fi

PUSHED_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      ;;
    *)
      PUSHED_ARGS+=("$1")
      shift
      ;;
  esac
done

load_config_file

BASES_TMPDIR="$(download_bases_archive)"

while IFS= read -r agent; do
  AICAGE_BASE_ALIASES="$(get_bases "${agent}" "${BASES_TMPDIR}/bases" "${AICAGE_BASE_ALIASES:-}")"
  for base_alias in ${AICAGE_BASE_ALIASES}; do
    echo "[build-all] Building ${agent}-${base_alias}" >&2
    "${ROOT_DIR}/scripts/debug/build.sh" \
      --agent "${agent}" \
      --base "${base_alias}" \
      "${PUSHED_ARGS[@]}"
  done
done < <(list_configured_agents)
