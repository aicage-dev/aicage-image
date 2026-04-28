#!/usr/bin/env bash
set -euo pipefail

# Build the refresh matrix for the workflow by checking each redistributable agent/base pair.
#
# Interface:
#   --aicage-version <tag>  Required release tag used in the final image names.
#   --force-build           Optional bypass for registry checks; every eligible pair is queued.
#
# Output:
#   stdout  Single-line JSON object for GitHub Actions matrix consumption.
#   stderr  Human-readable progress, diagnostics, and the pretty-printed matrix.
#
# Coordination model:
#   1. Cache base-image metadata once for all base aliases.
#   2. Launch one refresh-images/check.sh worker per agent/base pair.
#   3. Collect worker decisions in BUILD_LIST and convert them to matrix JSON.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

source "${ROOT_DIR}/scripts/common.sh"
source "${ROOT_DIR}/scripts/refresh-images/lib.sh"

AICAGE_VERSION=""
FORCE_BUILD=0

# Cache each base alias once with the data that every worker needs for rebuild comparison.
# The output is a TSV file with:
#   <base_alias> <arch> <manifest_digest> <last_layer_digest>
load_base_metadata_file() {
  local metadata_file="$1"
  local bases_dir="$2"
  local base_repo="${AICAGE_IMAGE_REGISTRY}/${AICAGE_IMAGE_BASE_REPOSITORY}"
  local base_alias
  local base_image
  local base_digest
  local base_last_layer

  : > "${metadata_file}"
  while IFS= read -r base_alias; do
    [[ -n "${base_alias}" ]] || continue
    base_image="${base_repo}:${base_alias}"
    for arch in amd64 arm64; do
      if ! base_digest="$(get_manifest_digest "${base_image}" "${arch}")"; then
        echo "Failed to load ${arch} digest for ${base_image}" >&2
        return 1
      fi
      if [[ -z "${base_digest}" ]]; then
        echo "Missing ${arch} digest for ${base_image}" >&2
        return 1
      fi

      if ! base_last_layer="$(get_last_layer "${base_repo}" "${base_digest}")"; then
        echo "Failed to load last layer for ${base_repo}@${base_digest}" >&2
        return 1
      fi
      if [[ -z "${base_last_layer}" ]]; then
        echo "Missing last layer for ${base_repo}@${base_digest}" >&2
        return 1
      fi

      printf '%s\t%s\t%s\t%s\n' \
        "${base_alias}" \
        "${arch}" \
        "${base_digest}" \
        "${base_last_layer}" >> "${metadata_file}"
    done
  done < <(list_base_aliases "${bases_dir}")
}

MAX_PARALLEL="${REFRESH_CHECKS_PARALLELISM:-12}"

# Temporary files shared by this orchestration run:
#   BASES_TMPDIR         Extracted base release artifact contents.
#   LOG_DIR              One log file per worker.
#   BUILD_LIST           TSV list of agent/base pairs selected for rebuild.
#   BUILD_LIST_LOCK      flock lock file protecting BUILD_LIST appends.
#   BASE_METADATA_FILE   Cached base metadata read by all workers.
BASES_TMPDIR="$(download_bases_archive)"
LOG_DIR="$(mktemp -d)"
BUILD_LIST="$(mktemp)"
BUILD_LIST_LOCK="$(mktemp)"
BASE_METADATA_FILE="$(mktemp)"
error_count=0
pids=()
declare -A pid_to_log pid_to_label

cleanup() {
  rm -rf "${BASES_TMPDIR}" "${LOG_DIR}"
  rm -f "${BUILD_LIST}" "${BUILD_LIST_LOCK}" "${BASE_METADATA_FILE}"
}
trap cleanup EXIT

# Derive filesystem-safe log filenames from agent/base labels.
log_name() {
  printf '%s' "$1" | tr -c '[:alnum:]_.-' '_'
}

# Emit worker output after completion so concurrent jobs do not interleave on stderr.
report_pid_result() {
  local pid="$1"
  local status="$2"

  if [[ "${status}" -ne 0 ]]; then
    error_count=$((error_count + 1))
    echo "Check failed: ${pid_to_label[${pid}]}" >&2
    sed 's/^/  /' "${pid_to_log[${pid}]}" >&2
  else
    cat "${pid_to_log[${pid}]}" >&2
  fi
}

wait_for_slot() {
  local finished_pid status

  # Keep at most MAX_PARALLEL background checks active at once.
  if [[ "${#pids[@]}" -ge "${MAX_PARALLEL}" ]]; then
    if wait -n -p finished_pid; then
      status=0
    else
      status=$?
    fi
    report_pid_result "${finished_pid}" "${status}"
    mapfile -t pids < <(jobs -p)
  fi
}

launch_check() {
  local agent="$1"
  local base_alias="$2"
  local agent_version="$3"
  local log_file
  local optional_args
  local pid

  log_file="${LOG_DIR}/$(log_name "${agent}_${base_alias}").log"

  # Keep the worker invocation explicit; only --force-build is optional.
  optional_args=""
  if (( FORCE_BUILD )); then
    optional_args="--force-build"
  fi

  "${ROOT_DIR}/scripts/refresh-images/check.sh" \
    --aicage-version "${AICAGE_VERSION}" \
    --agent "${agent}" \
    --base-alias "${base_alias}" \
    --agent-version "${agent_version}" \
    --build-list "${BUILD_LIST}" \
    --build-list-lock "${BUILD_LIST_LOCK}" \
    --base-metadata-file "${BASE_METADATA_FILE}" \
    ${optional_args} >"${log_file}" 2>&1 &
  pid="$!"
  pids+=("${pid}")
  pid_to_log["${pid}"]="${log_file}"
  pid_to_label["${pid}"]="${agent} (${base_alias})"

  wait_for_slot
}

enqueue_agent_checks() {
  local agent
  local agent_version
  local base_aliases
  local base_alias
  local dir

  for dir in agents/*; do
    [[ -d "${dir}" ]] || continue
    agent="$(basename "${dir}")"
    if is_agent_field_true "${agent}" build_local; then
      echo "Skipping non-redistributable agent ${agent}"
      continue
    fi

    agent_version="$(agents/"${agent}"/version.sh)"
    if [[ -z "${agent_version}" ]]; then
      echo "Agent version is empty for ${agent}" >&2
      exit 1
    fi

    base_aliases="$(get_bases "${agent}" "${BASES_TMPDIR}/bases")"
    for base_alias in ${base_aliases}; do
      launch_check "${agent}" "${base_alias}" "${agent_version}"
    done
  done
}

wait_for_checks() {
  local pid

  for pid in "${pids[@]}"; do
    if wait "${pid}"; then
      report_pid_result "${pid}" 0
    else
      report_pid_result "${pid}" $?
    fi
  done
}

build_matrix_json() {
  local build_matrix_file
  local build_count
  local build_matrix_json
  local agent
  local base_alias

  build_matrix_file="$(mktemp)"
  echo '{"include":[]}' > "${build_matrix_file}"
  while IFS=$'\t' read -r agent base_alias; do
    [[ -n "${agent}" ]] || continue
    # GitHub Actions expects a single JSON object with an `include` array.
    jq -c \
      --arg agent "${agent}" \
      --arg base "${base_alias}" \
      '
        .include += [
          {
            "agent": $agent,
            "base": $base
          }
        ]
      ' \
      "${build_matrix_file}" > "${build_matrix_file}.tmp"
    mv "${build_matrix_file}.tmp" "${build_matrix_file}"
  done < "${BUILD_LIST}"

  build_count="$(jq -r '.include | length' "${build_matrix_file}")"
  if [[ "${build_count}" -eq 0 ]]; then
    echo "No image rebuilds required." >&2
  fi
  build_matrix_json="$(cat "${build_matrix_file}")"
  echo "Build matrix:" >&2
  jq '.' "${build_matrix_file}" >&2
  printf '%s\n' "${build_matrix_json}"
}

main() {
  [[ -n "${AICAGE_VERSION}" ]] || _die "AICAGE_VERSION argument required"

  load_config_file

  if ! load_base_metadata_file "${BASE_METADATA_FILE}" "${BASES_TMPDIR}/bases"; then
    echo "Failed to load base metadata." >&2
    exit 1
  fi

  enqueue_agent_checks
  wait_for_checks

  if [[ "${error_count}" -gt 0 ]]; then
    echo "Refresh checks reported ${error_count} error(s)." >&2
    exit 1
  fi

  build_matrix_json
}

# Parse the small public CLI, then hand off to main with state in named variables.
while [[ $# -gt 0 ]]; do
  case "$1" in
    --aicage-version)
      AICAGE_VERSION="${2:-}"
      shift 2
      ;;
    --force-build)
      FORCE_BUILD=1
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      _die "Unknown argument: $1"
      ;;
  esac
done

main
