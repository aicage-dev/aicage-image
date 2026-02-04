#!/usr/bin/env bats

setup() {
  ROOT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
  if [[ -z "${AGENT:-}" ]]; then
    echo "AGENT must be provided to the test suite" >&2
    exit 1
  fi

  AGENT_METADATA_FILE="${ROOT_DIR}/agents/${AGENT}/agent.yml"
  if [[ ! -f "${AGENT_METADATA_FILE}" ]]; then
    echo "Metadata file not found for agent '${AGENT}'" >&2
    exit 1
  fi
}

@test "test_boots_container" {
  run docker run --rm \
    --env AICAGE_ENTRYPOINT_CMD=/bin/bash \
    --env AICAGE_WORKSPACE=/workspace \
    "${AICAGE_IMAGE}" \
    -c "echo ${AGENT}-boot && whoami"
  [ "$status" -eq 0 ]
  [[ "$output" == *"${AGENT}-boot"* ]]
}

@test "test_agent_binary_present" {
  run docker run --rm \
    --env AICAGE_ENTRYPOINT_CMD=/bin/bash \
    --env AICAGE_WORKSPACE=/workspace \
    "${AICAGE_IMAGE}" \
    -c "command -v ${AGENT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"${AGENT}"* ]]
}

@test "test_required_packages" {
  run docker run --rm \
    --env AICAGE_ENTRYPOINT_CMD=/bin/bash \
    --env AICAGE_WORKSPACE=/workspace \
    "${AICAGE_IMAGE}" \
    -c \
    "git --version >/dev/null && python3 --version >/dev/null && node --version >/dev/null && npm --version >/dev/null"
  [ "$status" -eq 0 ]
}
