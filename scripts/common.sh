#!/usr/bin/env bash
set -euo pipefail

AGENT_DEFINITIONS_DIR="${ROOT_DIR}/agents"

_die() {
  if command -v die >/dev/null 2>&1; then
    die "$@"
  else
    echo "[common] $*" >&2
    exit 1
  fi
}

# add retry and other params to reduce failure in pipelines
curl_wrapper() {
  curl -fsSL \
    --retry 8 \
    --retry-all-errors \
    --retry-delay 2 \
    --max-time 600 \
    "$@"
}

load_config_file() {
  local config_file="${ROOT_DIR}/config.yml"
  [[ -f "${config_file}" ]] || _die "Config file not found: ${config_file}"

  while IFS=$'\t' read -r key value; do
    [[ -z "${key}" ]] && continue
    if [[ -z ${!key+x} ]]; then
      export "${key}=${value}"
    fi
  done < <(yq -er 'to_entries[] | [.key, (.value // "")] | @tsv' "${config_file}")
}

get_agent_field() {
  local agent="$1"
  local field="$2"
  local agent_dir="${AGENT_DEFINITIONS_DIR}/${agent}"
  local definition_file="${agent_dir}/agent.yml"

  [[ -d "${agent_dir}" ]] || _die "Agent '${agent}' not found under ${AGENT_DEFINITIONS_DIR}"
  [[ -f "${definition_file}" ]] || _die "Missing agent.yml for '${agent}'"

  local value
  value="$(yq -r ".${field}" "${definition_file}")" || _die "Failed to read ${field} from ${definition_file}"
  [[ -n "${value}" && "${value}" != "null" ]] || _die "${field} missing in ${definition_file}"
  printf '%s\n' "${value}"
}

is_agent_field_true() {
  local agent="$1"
  local field="$2"
  local value
  value="$(get_agent_field "${agent}" "${field}")"
  [[ "${value}" == "true" ]]
}

get_agent_list_field() {
  local agent="$1"
  local field="$2"
  local agent_dir="${AGENT_DEFINITIONS_DIR}/${agent}"
  local definition_file="${agent_dir}/agent.yml"

  [[ -d "${agent_dir}" ]] || _die "Agent '${agent}' not found under ${AGENT_DEFINITIONS_DIR}"
  [[ -f "${definition_file}" ]] || _die "Missing agent.yml for '${agent}'"

  yq -r ".${field} // [] | .[]" "${definition_file}" \
    || _die "Failed to read ${field} from ${definition_file}"
}

download_bases_archive() {
  local tmpdir
  local base_repo="${AICAGE_IMAGE_BASE_REPOSITORY##*/}"

  tmpdir="$(mktemp -d)" || _die "Failed to create temp dir"

  "${ROOT_DIR}"/scripts/get-aicage-release-artifact.sh "${base_repo}" "${tmpdir}"

  printf '%s\n' "${tmpdir}"
}

get_base_list_field() {
  local bases_dir="$1"
  local alias="$2"
  local field="$3"
  local definition_file="${bases_dir}/${alias}/base.yml"

  [[ -f "${definition_file}" ]] || _die "Missing base.yml for ${alias} in ${bases_dir}"

  yq -r ".${field} // [] | .[]" "${definition_file}" \
    || _die "Failed to read ${field} from ${definition_file}"
}

list_base_aliases() {
  local bases_dir="$1"

  [[ -d "${bases_dir}" ]] || _die "Bases directory not found: ${bases_dir}"

  shopt -s nullglob
  for dir in "${bases_dir}"/*/; do
    basename "${dir}"
  done | sort -u
  shopt -u nullglob
}

normalize_value() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

list_contains() {
  local needle="$1"
  shift
  local item

  for item in "$@"; do
    if [[ "${item}" == "${needle}" ]]; then
      return 0
    fi
  done

  return 1
}

get_base_architectures() {
  local bases_dir="$1"
  local alias="$2"
  get_base_list_field "${bases_dir}" "${alias}" architectures
}

get_bases() {
  local agent="$1"
  local bases_dir="$2"
  local base_list="${3:-}"
  local base_aliases
  local -a base_exclude base_distro_exclude
  local alias alias_lc base_yaml distro distro_lc

  [[ -n "${agent}" ]] || _die "Agent name required for base discovery"
  [[ -n "${bases_dir}" ]] || _die "Bases directory required for base discovery"

  if [[ -n "${base_list}" ]]; then
    base_aliases="${base_list}"
  else
    base_aliases="$(list_base_aliases "${bases_dir}")"
  fi

  mapfile -t base_exclude < <(
    get_agent_list_field "${agent}" base_exclude | tr '[:upper:]' '[:lower:]'
  )
  mapfile -t base_distro_exclude < <(
    get_agent_list_field "${agent}" base_distro_exclude | tr '[:upper:]' '[:lower:]'
  )

  while IFS= read -r alias; do
    [[ -n "${alias}" ]] || continue
    alias_lc="$(normalize_value "${alias}")"
    if list_contains "${alias_lc}" "${base_exclude[@]:-}"; then
      continue
    fi

    if [[ ${#base_distro_exclude[@]} -gt 0 ]]; then
      base_yaml="${bases_dir}/${alias}/base.yml"
      [[ -f "${base_yaml}" ]] || _die "Missing base.yml for ${alias} in ${bases_dir}"
      distro="$(yq -er '.base_image_distro' "${base_yaml}")" \
        || _die "Failed to read base_image_distro from ${base_yaml}"
      distro_lc="$(normalize_value "${distro}")"
      if list_contains "${distro_lc}" "${base_distro_exclude[@]}"; then
        continue
      fi
    fi

    printf '%s\n' "${alias}"
  done <<< "${base_aliases}"
}
