#!/usr/bin/env bash
set -euo pipefail

get_manifest_digest() {
  local image="$1"
  local arch="$2"
  local manifest
  local digest

  if ! manifest="$(run_cmd "skopeo inspect --raw ${image}" \
    skopeo inspect --raw "docker://${image}")"; then
    return 1
  fi

  if ! digest="$(run_cmd "jq digest ${image} ${arch}" \
    jq -r --arg arch "${arch}" ".manifests[]? | select(.platform.architecture == \$arch) | .digest" \
    <<<"${manifest}")"; then
    return 1
  fi

  printf '%s\n' "${digest}" | head -n 1
}

get_last_layer() {
  local image_repo="$1"
  local digest="$2"
  local manifest
  local layer

  if ! manifest="$(run_cmd "skopeo inspect ${image_repo}@${digest}" \
    skopeo inspect "docker://${image_repo}@${digest}")"; then
    return 1
  fi

  if ! layer="$(run_cmd "jq layers ${image_repo}@${digest}" \
    jq -r '.Layers[]' <<<"${manifest}")"; then
    return 1
  fi

  printf '%s\n' "${layer}" | tail -n 1
}

run_cmd() {
  local label="$1"
  shift
  local out_file err_file status

  out_file="$(mktemp)"
  err_file="$(mktemp)"
  if "$@" >"${out_file}" 2>"${err_file}"; then
    cat "${out_file}"
    rm -f "${out_file}" "${err_file}"
    return 0
  fi

  status=$?
  echo "Command failed (${label}) [exit ${status}]" >&2
  echo "  $*" >&2
  if [[ -s "${err_file}" ]]; then
    sed 's/^/  /' "${err_file}" >&2
  fi
  rm -f "${out_file}" "${err_file}"
  return "${status}"
}

check_final_image_presence() {
  local final_image="$1"
  local presence_status

  if "${ROOT_DIR}/scripts/image-presence-check.sh" "${final_image}"; then
    return 1
  fi
  presence_status=$?

  case "${presence_status}" in
    10)
      return 0
      ;;
    *)
      echo "Failed to inspect ${final_image}" >&2
      return 2
      ;;
  esac
}

needs_rebuild() {
  local base_image_tag="$1"
  local final_image_tag="$2"
  local base_repo="${AICAGE_IMAGE_REGISTRY}/${AICAGE_IMAGE_BASE_REPOSITORY}"
  local final_repo="${AICAGE_IMAGE_REGISTRY}/${AICAGE_IMAGE_REPOSITORY}"
  local base_image="${base_repo}:${base_image_tag}"
  local final_image="${final_repo}:${final_image_tag}"

  echo "[needs-rebuild]: base_image=${base_image}" >&2
  echo "[needs-rebuild]: final_image=${final_image}" >&2

  if check_final_image_presence "${final_image}"; then
    echo "${final_image} is missing"
    return 0
  fi
  case "$?" in
    1)
      ;;
    *)
      return 2
      ;;
  esac

  for arch in amd64 arm64; do
    local base_digest
    if ! base_digest="$(get_manifest_digest "${base_image}" "${arch}")"; then
      echo "Failed to get ${arch} digest for ${base_image}" >&2
      return 2
    fi
    if [[ -z "${base_digest}" ]]; then
      echo "Missing ${arch} digest for ${base_image}"
      return 0
    fi

    local final_digest
    if ! final_digest="$(get_manifest_digest "${final_image}" "${arch}")"; then
      echo "Failed to get ${arch} digest for ${final_image}" >&2
      return 2
    fi
    if [[ -z "${final_digest}" ]]; then
      echo "Missing ${arch} digest for ${final_image}"
      return 0
    fi

    local base_last_layer
    if ! base_last_layer="$(get_last_layer "${base_repo}" "${base_digest}")"; then
      echo "Failed to get last layer for ${base_repo}@${base_digest}" >&2
      return 2
    fi
    if [[ -z "${base_last_layer}" ]]; then
      echo "Missing last layer for ${base_repo}@${base_digest}"
      return 0
    fi

    local final_layers
    if ! final_layers="$(run_cmd "skopeo inspect ${final_repo}@${final_digest}" \
      skopeo inspect "docker://${final_repo}@${final_digest}")"; then
      return 2
    fi
    if ! final_layers="$(run_cmd "jq layers ${final_repo}@${final_digest}" \
      jq -r '.Layers[]' <<<"${final_layers}")"; then
      return 2
    fi

    if ! printf '%s\n' "${final_layers}" | grep -Fxq "${base_last_layer}"; then
      echo "${final_repo}@${final_digest} missing base layer ${base_last_layer} (${arch})"
      return 0
    fi
  done

  return 1
}
