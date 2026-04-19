#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <image-ref>" >&2
  exit 64
fi

image="$1"
out_file="$(mktemp)"
err_file="$(mktemp)"
trap 'rm -f "${out_file}" "${err_file}"' EXIT
command_timeout="${SKOPEO_COMMAND_TIMEOUT:-60s}"
retry_times="${SKOPEO_RETRY_TIMES:-3}"

set +e
skopeo \
  --command-timeout "${command_timeout}" \
  inspect \
  --retry-times "${retry_times}" \
  --no-tags \
  "docker://${image}" >"${out_file}" 2>"${err_file}"
status=$?
set -e

if [[ "${status}" -eq 0 ]]; then
  exit 0
fi

output="$(cat "${err_file}")"
normalized_output="$(printf '%s' "${output}" | tr '[:upper:]' '[:lower:]')"

if [[ "${normalized_output}" == *"manifest unknown"* ]] \
  || [[ "${normalized_output}" == *"name unknown"* ]] \
  || [[ "${normalized_output}" == *"statuscode: 404"* ]] \
  || [[ "${normalized_output}" == *"404 not found"* ]] \
  || [[ "${normalized_output}" == *"404 (not found)"* ]]; then
  echo "Image missing: ${image}" >&2
  exit 10
fi

echo "Command failed (skopeo inspect ${image}) [exit ${status}]" >&2
echo "  skopeo --command-timeout ${command_timeout} inspect --retry-times ${retry_times} --no-tags docker://${image}" >&2
if [[ -n "${output}" ]]; then
  sed 's/^/  /' "${err_file}" >&2
fi
exit 20
