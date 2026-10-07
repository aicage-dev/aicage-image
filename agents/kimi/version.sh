#!/usr/bin/env bash
set -euo pipefail

curl \
  -fsSL \
  --retry 8 \
  --retry-all-errors \
  --retry-delay 2 \
  --max-time 300 \
  https://code.kimi.com/kimi-code/latest
