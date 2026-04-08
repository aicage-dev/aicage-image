#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

die() {
  echo "[test-all] $*" >&2
  exit 1
}

# shellcheck source=./scripts/common.sh
source "${ROOT_DIR}/scripts/common.sh"

load_config_file

BASES_TMPDIR="$(download_bases_archive)"
AGENTS_DIR="${ROOT_DIR}/agents"

for agent_dir in "${AGENTS_DIR}"/*; do
  AGENT="$(basename "${agent_dir}")"
  AICAGE_BASE_ALIASES="$(get_bases "${AGENT}" "${BASES_TMPDIR}/bases" "${AICAGE_BASE_ALIASES:-}")"
  for BASE_ALIAS in ${AICAGE_BASE_ALIASES}; do
    IMAGE="${AICAGE_IMAGE_REPOSITORY}:${AGENT}-${BASE_ALIAS}"
    echo "[test-all] Testing ${IMAGE}" >&2
    "${ROOT_DIR}/scripts/test.sh" --image "${IMAGE}" --agent "${AGENT}" "$@"
  done
done
