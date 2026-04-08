#!/usr/bin/env bash
set -euo pipefail

release_tag="$(
  curl \
    -fsSL \
    --retry 8 \
    --retry-all-errors \
    --retry-delay 2 \
    --max-time 300 \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${GITHUB_REPOSITORY}/releases/latest" \
  | jq -r '.tag_name'
)"

if [[ -z "${release_tag}" ]]; then
  echo "Latest release tag is empty." >&2
  exit 1
fi

printf '%s\n' "${release_tag}"
