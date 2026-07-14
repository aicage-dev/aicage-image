#!/usr/bin/env bash
set -euo pipefail

# Prerequisites:
# - cosign
# - curl
# - tar

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=./scripts/common.sh
source "${ROOT_DIR}/scripts/common.sh"
load_config_file

AICAGE_REPO="$1"
TARGET_DIR="$2"
ARTIFACT_NAME="${3:-${AICAGE_REPO}.tar.gz}"
REPOSITORY_URL="$(get_image_base_source_url)"
RELEASE_WORKFLOW_IDENTITY_REGEXP="$(get_release_workflow_identity_regexp "${AICAGE_IMAGE_BASE_SOURCE_REPOSITORY}")"

mkdir -p "${TARGET_DIR}"
pushd "${TARGET_DIR}" >/dev/null

echo "Downloading release artifact from '${REPOSITORY_URL}' to ${TARGET_DIR} ..." >&2

for artifact in "${ARTIFACT_NAME}" SHA256SUMS SHA256SUMS.sigstore.json; do
  curl -fsSLO \
    --retry 8 \
    --retry-all-errors \
    --retry-delay 2 \
    --max-time 600 \
    "${REPOSITORY_URL}/releases/latest/download/${artifact}"
done

echo "Verifying signature ..." >&2

cosign verify-blob \
  --bundle SHA256SUMS.sigstore.json \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  --certificate-identity-regexp "${RELEASE_WORKFLOW_IDENTITY_REGEXP}" \
  SHA256SUMS \
  >&2

echo "Verifying checksums ..." >&2

grep "  \\./${ARTIFACT_NAME}$" SHA256SUMS | sha256sum -c - >&2

echo "Unpacking ..." >&2

tar -xzf "${ARTIFACT_NAME}" >&2

echo "Clean up ..." >&2

rm "${ARTIFACT_NAME}" SHA256SUMS SHA256SUMS.sigstore.json >&2

popd >/dev/null

echo "Done downloading release artifact from '${REPOSITORY_URL}' to ${TARGET_DIR}" >&2
