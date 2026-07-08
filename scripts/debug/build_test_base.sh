#!/usr/bin/env bash

set -euo pipefail

BASE="$1"

# shellcheck source=./scripts/common.sh
source scripts/common.sh
load_config_file

echo "Testing base: ${BASE}"

while IFS= read -r agent; do

  echo "Testing agent: ${agent}"

  scripts/debug/build.sh --base "${BASE}" --agent "${agent}" \
    || ( echo "Build agent ${agent} failed" && false )

  image_ref="$(get_image_ref)"
  scripts/test.sh --image "${image_ref}:${agent}-${BASE}" --agent "${agent}" \
    || ( echo "Testing agent ${agent} failed" && false )
done < <(list_configured_agents)
