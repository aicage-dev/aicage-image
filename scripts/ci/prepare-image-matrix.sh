#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
: "${RUNNER_AMD64:?RUNNER_AMD64 is required}"
: "${RUNNER_ARM64:?RUNNER_ARM64 is required}"

die() {
  echo "[prepare-image-matrix] $*" >&2
  exit 1
}

# shellcheck source=./scripts/common.sh
source "${ROOT_DIR}/scripts/common.sh"
load_config_file

bases_tmpdir="$(download_bases_archive)"
full_images_file="$(mktemp)"
echo '{"include":[]}' >"${full_images_file}"

while IFS= read -r agent; do
  build_local="$(get_agent_field "${agent}" build_local)"
  base_aliases="$(get_bases "${agent}" "${bases_tmpdir}/bases")"
  for base_alias in ${base_aliases}; do
    while IFS= read -r arch; do
      [[ -n "${arch}" ]] || continue
      case "${arch}" in
        amd64)
          platform="linux/amd64"
          runner="${RUNNER_AMD64}"
          ;;
        arm64)
          platform="linux/arm64"
          runner="${RUNNER_ARM64}"
          ;;
        *)
          die "Unsupported architecture '${arch}' for ${base_alias}"
          ;;
      esac

      jq -c \
        --arg agent "${agent}" \
        --arg base "${base_alias}" \
        --arg arch "${arch}" \
        --arg platform "${platform}" \
        --arg runner "${runner}" \
        --argjson build_local "${build_local}" \
        '
          .include += [
            {
              "agent": $agent,
              "base": $base,
              "arch": $arch,
              "platform": $platform,
              "runner": $runner,
              "build_local": $build_local
            }
          ]
        ' \
        "${full_images_file}" >"${full_images_file}.tmp"
      mv "${full_images_file}.tmp" "${full_images_file}"
    done < <(get_base_architectures "${bases_tmpdir}/bases" "${base_alias}")
  done
done < <(list_configured_agents)

images_file="$(mktemp)"
nr_images_file="$(mktemp)"

jq -c \
  '{include: ([.include[] | select(.build_local == false) | {agent, base}] | unique)}' \
  "${full_images_file}" >"${images_file}"
jq -c \
  '{include: [.include[] | select(.build_local == true) | del(.build_local)]}' \
  "${full_images_file}" >"${nr_images_file}"

echo "Redistributable image matrix:" >&2
jq '.' "${images_file}" >&2
echo "Non-redistributable image matrix:" >&2
jq '.' "${nr_images_file}" >&2

printf 'MATRIX_IMAGES=%s\n' "$(cat "${images_file}")"
printf 'MATRIX_NR_IMAGES=%s\n' "$(cat "${nr_images_file}")"
