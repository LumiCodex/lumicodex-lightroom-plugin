#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${1:-}"

if [[ -z "$version" ]]; then
  echo "Usage: publish.sh VERSION" >&2
  exit 2
fi
if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI is required to publish the Lightroom plugin." >&2
  exit 1
fi

archive="$($project_root/scripts/package.sh "$version")"
destination="s3://lc-media-eu-we-1/lumicodex/$version-lightroom/$(basename "$archive")"
aws s3 cp "$archive" "$destination" --content-type application/zip
echo "$destination"
