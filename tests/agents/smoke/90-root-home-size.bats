#!/usr/bin/env bats

@test "root home stays small" {
  run docker run --rm \
    --entrypoint /bin/bash \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail

      max_root_kib=8192
      root_kib="$(du -sk /root | cut -f1)"

      if [[ "${root_kib}" -gt "${max_root_kib}" ]]; then
        echo "/root is ${root_kib} KiB; expected at most ${max_root_kib} KiB" >&2
        du -ak /root | sort -n | tail -20 >&2
        exit 1
      fi
    '
  [ "$status" -eq 0 ]
}
