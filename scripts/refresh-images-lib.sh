#!/usr/bin/env bash
set -euo pipefail

get_manifest_digest() {
  local image="$1"
  local arch="$2"
  local manifest
  local digest

  if ! manifest="$(skopeo_inspect --raw "docker://${image}")"; then
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

  if ! manifest="$(skopeo_inspect --no-tags "docker://${image_repo}@${digest}")"; then
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
  else
    status=$?
  fi

  echo "Command failed (${label}) [exit ${status}]" >&2
  echo "  $*" >&2
  if [[ -s "${err_file}" ]]; then
    sed 's/^/  /' "${err_file}" >&2
  fi
  rm -f "${out_file}" "${err_file}"
  return "${status}"
}

skopeo_inspect() {
  run_cmd "skopeo inspect $*" \
    skopeo --command-timeout 60s inspect --retry-times 3 "$@"
}

read_base_metadata_field() {
  local metadata_file="$1"
  local base_alias="$2"
  local arch="$3"
  local field="$4"
  local field_index

  case "${field}" in
    digest)
      field_index=3
      ;;
    last_layer)
      field_index=4
      ;;
    *)
      echo "Unknown base metadata field: ${field}" >&2
      return 1
      ;;
  esac

  awk -F '\t' \
    -v base_alias="${base_alias}" \
    -v arch="${arch}" \
    -v field_index="${field_index}" \
    '$1 == base_alias && $2 == arch { print $field_index; found = 1; exit }
     END { if (!found) exit 1 }' \
    "${metadata_file}"
}


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

      printf '%s\t%s\t%s\t%s\n' "${base_alias}" "${arch}" "${base_digest}" "${base_last_layer}" >> "${metadata_file}"
    done
  done < <(list_base_aliases "${bases_dir}")
}


needs_rebuild() {
  local base_image_tag="$1"
  local final_image_tag="$2"
  local base_metadata_file="$3"
  local base_repo="${AICAGE_IMAGE_REGISTRY}/${AICAGE_IMAGE_BASE_REPOSITORY}"
  local final_repo="${AICAGE_IMAGE_REGISTRY}/${AICAGE_IMAGE_REPOSITORY}"
  local base_image="${base_repo}:${base_image_tag}"
  local final_image="${final_repo}:${final_image_tag}"

  echo "[needs-rebuild]: base_image=${base_image}" >&2
  echo "[needs-rebuild]: final_image=${final_image}" >&2

  if ! skopeo_inspect --no-tags "docker://${final_image}" >/dev/null; then
    echo "${final_image} is missing"
    return 0
  fi

  for arch in amd64 arm64; do
    local base_digest
    if ! base_digest="$(read_base_metadata_field "${base_metadata_file}" "${base_image_tag}" "${arch}" digest)"; then
      echo "Missing cached ${arch} digest for ${base_image}" >&2
      return 2
    fi
    if [[ -z "${base_digest}" ]]; then
      echo "Missing cached ${arch} digest for ${base_image}" >&2
      return 2
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
    if ! base_last_layer="$(read_base_metadata_field "${base_metadata_file}" "${base_image_tag}" "${arch}" last_layer)"; then
      echo "Missing cached last layer for ${base_image} (${arch})" >&2
      return 2
    fi
    if [[ -z "${base_last_layer}" ]]; then
      echo "Missing cached last layer for ${base_image} (${arch})" >&2
      return 2
    fi

    local final_layers
    if ! final_layers="$(skopeo_inspect --no-tags "docker://${final_repo}@${final_digest}")"; then
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
