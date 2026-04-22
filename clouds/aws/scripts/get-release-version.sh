#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  bash clouds/aws/scripts/get-release-version.sh

Description:
  Resolves the normalized Penpot release version to use for AMI naming/tagging.

Resolution order:
  1. PENPOT_RELEASE_VERSION environment variable
  2. RELEASE_VERSION environment variable
  3. PENPOT_RELEASE_TAG environment variable

Normalization:
  - strips a leading "v" from versions like v1.2.3
  - fails if no Penpot release version is provided
USAGE
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

raw_version="${PENPOT_RELEASE_VERSION:-${RELEASE_VERSION:-${PENPOT_RELEASE_TAG:-}}}"

if [[ -z "$raw_version" ]]; then
  echo "unable to resolve Penpot release version from environment" >&2
  exit 1
fi

normalized_version="${raw_version#v}"

if [[ -z "$normalized_version" ]]; then
  echo "resolved Penpot release version is empty after normalization" >&2
  exit 1
fi

echo "$normalized_version"
