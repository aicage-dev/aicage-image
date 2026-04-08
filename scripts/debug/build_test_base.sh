#!/usr/bin/env bash

set -euo pipefail

BASE="$1"

echo "Testing base: ${BASE}"

for dir in agents/*; do
  agent="$(basename "${dir}")"

  echo "Testing agent: ${agent}"

  scripts/debug/build.sh --base "${BASE}" --agent "${agent}" \
    || ( echo "Build agent ${agent} failed" && false )

  scripts/test.sh --image "aicage/aicage:${agent}-${BASE}" --agent "${agent}" \
    || ( echo "Testing agent ${agent} failed" && false )
done
