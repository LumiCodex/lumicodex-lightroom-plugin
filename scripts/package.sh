#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${1:-}"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$ ]]; then
  echo "Usage: package.sh VERSION (for example 1.0.0)" >&2
  exit 2
fi

if ! command -v zip >/dev/null 2>&1; then
  echo "zip is required to package the Lightroom plugin." >&2
  exit 1
fi

dist_dir="$project_root/dist"
archive="$dist_dir/lumicodex-lightroom-plugin-$version.zip"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

mkdir -p "$dist_dir" "$work_dir/package"
cp -R "$project_root/LumiCodex.lrplugin" "$work_dir/package/"
cp "$project_root/README.md" "$project_root/CHANGELOG.md" "$project_root/VALIDATION.md" "$project_root/THIRD_PARTY_NOTICES.md" "$work_dir/package/"

(cd "$work_dir/package" && zip -qr "$archive" .)
echo "$archive"
