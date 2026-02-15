#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 --version <version> --arm-sha <sha256> --intel-sha <sha256> --output <path> [--repo <owner/repo>]
EOF
}

VERSION=""
ARM_SHA=""
INTEL_SHA=""
OUTPUT_PATH=""
REPO="RuiAAPeres/GitTracker"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="$2"
      shift 2
      ;;
    --arm-sha)
      ARM_SHA="$2"
      shift 2
      ;;
    --intel-sha)
      INTEL_SHA="$2"
      shift 2
      ;;
    --output)
      OUTPUT_PATH="$2"
      shift 2
      ;;
    --repo)
      REPO="$2"
      shift 2
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$VERSION" || -z "$ARM_SHA" || -z "$INTEL_SHA" || -z "$OUTPUT_PATH" ]]; then
  usage
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"

cat >"$OUTPUT_PATH" <<EOF
cask "gittracker" do
  version "${VERSION}"

  on_arm do
    sha256 "${ARM_SHA}"
    url "https://github.com/${REPO}/releases/download/v#{version}/GitTracker-arm64.zip"
  end

  on_intel do
    sha256 "${INTEL_SHA}"
    url "https://github.com/${REPO}/releases/download/v#{version}/GitTracker-x86_64.zip"
  end

  name "GitTracker"
  desc "Menu bar app for git working tree thresholds"
  homepage "https://github.com/${REPO}"

  app "GitTracker.app"
end
EOF

echo "Updated cask at $OUTPUT_PATH"

