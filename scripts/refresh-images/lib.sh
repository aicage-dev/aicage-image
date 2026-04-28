#!/usr/bin/env bash
set -euo pipefail

# Shared low-level helpers for refresh-image scripts.
#
# Scope:
#   These functions hide the repetitive skopeo + jq plumbing used by matrix.sh and check.sh.
#   They do not know anything about agents, bases, or rebuild decisions.
#
# Conventions:
#   Successful helpers write their primary value to stdout and return 0.
#   Failures return non-zero and emit a contextual error message on stderr.

# Resolve the architecture-specific manifest digest from a multi-arch image reference.
# Arguments:
#   $1  Full image reference without the docker:// prefix, for example ghcr.io/org/repo:tag
#   $2  Architecture name, currently amd64 or arm64
# Output:
#   stdout  First matching manifest digest
get_manifest_digest() {
  local image="$1"
  local arch="$2"
  local manifest
  local digest

  if ! manifest="$(skopeo_inspect --raw "docker://${image}")"; then
    return 1
  fi

  if ! digest="$(run_cmd "jq digest ${image} ${arch}" \
    jq -r --arg arch "${arch}" ".manifests[]? | select(.platform.architecture == \$arch) | .digest" \
    <<<"${manifest}")"; then
    return 1
  fi

  printf '%s\n' "${digest}" | head -n 1
}

# Resolve the last layer digest from a manifest identified by digest.
# This is used as the base-layer fingerprint when deciding whether a final image still embeds
# the current base image for a given architecture.
# Arguments:
#   $1  Image repository without tag, for example ghcr.io/org/repo
#   $2  Manifest digest
# Output:
#   stdout  Last layer digest
get_last_layer() {
  local image_repo="$1"
  local digest="$2"
  local manifest
  local layer

  if ! manifest="$(skopeo_inspect --no-tags "docker://${image_repo}@${digest}")"; then
    return 1
  fi

  if ! layer="$(run_cmd "jq layers ${image_repo}@${digest}" \
    jq -r '.Layers[]' <<<"${manifest}")"; then
    return 1
  fi

  printf '%s\n' "${layer}" | tail -n 1
}

# Run a command, capture stdout/stderr separately, and upgrade failures with a stable label.
# This keeps the caller-facing errors readable while still returning raw stdout on success.
# Arguments:
#   $1    Human-readable label used in error output
#   $2+   Command to execute
run_cmd() {
  local label="$1"
  shift
  local out_file err_file status

  out_file="$(mktemp)"
  err_file="$(mktemp)"
  if "$@" >"${out_file}" 2>"${err_file}"; then
    cat "${out_file}"
    rm -f "${out_file}" "${err_file}"
    return 0
  else
    status=$?
  fi

  echo "Command failed (${label}) [exit ${status}]" >&2
  echo "  $*" >&2
  if [[ -s "${err_file}" ]]; then
    sed 's/^/  /' "${err_file}" >&2
  fi
  rm -f "${out_file}" "${err_file}"
  return "${status}"
}

# Wrapper around skopeo inspect with a timeout and retries suitable for CI registry checks.
# All arguments are forwarded directly to `skopeo inspect`.
skopeo_inspect() {
  run_cmd "skopeo inspect $*" \
    skopeo --command-timeout 60s inspect --retry-times 3 "$@"
}
