#!/usr/bin/env bash
set -euo pipefail

curl \
  -fsSL \
  --retry 8 \
  --retry-all-errors \
  --retry-delay 2 \
  --max-time 300 \
  https://code.kimi.com/kimi-code/install.sh |
  KIMI_INSTALL_DIR=/usr/local \
    KIMI_NO_MODIFY_PATH=1 \
    bash

install -d /usr/share/licenses/kimi

curl \
  -fsSL \
  --retry 8 \
  --retry-all-errors \
  --retry-delay 2 \
  --max-time 300 \
  https://raw.githubusercontent.com/MoonshotAI/kimi-code/refs/heads/main/LICENSE \
  -o /usr/share/licenses/kimi/LICENSE
