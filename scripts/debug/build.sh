#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

die() {
  echo "[build] $*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage: scripts/debug/build.sh --agent <agent> --base <alias> [options]

Options:
  --agent <value>      Agent name to build (required)
  --base <value>       Base alias to consume (required; must match available base tags)
  -h, --help           Show this help and exit

Examples:
  scripts/debug/build.sh --agent cline --base fedora
  scripts/debug/build.sh --agent codex --base ubuntu
USAGE
  exit 1
}

# shellcheck source=./scripts/common.sh
source "${ROOT_DIR}/scripts/common.sh"

AGENT=""
BASE_ALIAS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent)
      [[ $# -ge 2 ]] || die "--agent requires a value"
      AGENT="$2"
      shift 2
      ;;
    --base)
      [[ $# -ge 2 ]] || die "--base requires a value"
      BASE_ALIAS="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    --)
      shift
      break
      ;;
    *)
      die "Unknown option '$1'"
      ;;
  esac
done

[[ -n "${AGENT}" && -n "${BASE_ALIAS}" ]] || die "--agent and --base are required"

load_config_file

BASES_TMPDIR="$(download_bases_archive)"
ALLOWED_BASES="$(get_bases "${AGENT}" "${BASES_TMPDIR}/bases" "${BASE_ALIAS}")"
if ! printf '%s\n' "${ALLOWED_BASES}" | grep -Fxq "${BASE_ALIAS}"; then
  die "Base '${BASE_ALIAS}' is excluded for agent '${AGENT}'"
fi

BASE_IMAGE="${AICAGE_IMAGE_REGISTRY}/${AICAGE_IMAGE_BASE_REPOSITORY}:${BASE_ALIAS}"
AGENT_VERSION="$("${ROOT_DIR}/agents/${AGENT}/version.sh")"
[[ -n "${AGENT_VERSION}" ]] || die "Agent version is empty for ${AGENT}"
VERSION_TAG="${AICAGE_IMAGE_REPOSITORY}:${AGENT}-${BASE_ALIAS}-${AGENT_VERSION}"
LATEST_TAG="${AICAGE_IMAGE_REPOSITORY}:${AGENT}-${BASE_ALIAS}"

(
  echo "[build] Agent=${AGENT}"
  echo "Base=${BASE_ALIAS}"
  echo "Repo=${AICAGE_IMAGE_REPOSITORY}"
  echo "Version=${AGENT_VERSION}"
  echo "BaseImage=${BASE_IMAGE}"
  echo "Tags=${VERSION_TAG},${LATEST_TAG}"
) >&2

docker build \
  --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
  --build-arg "AGENT=${AGENT}" \
  --label "org.opencontainers.image.description=Agent image for ${AGENT}" \
  --tag "${VERSION_TAG}" \
  --tag "${LATEST_TAG}" \
  "${ROOT_DIR}"
