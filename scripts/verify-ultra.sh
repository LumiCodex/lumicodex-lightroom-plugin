#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: verify-ultra.sh FILE.avif|FILE.jxl [...]" >&2
  exit 2
fi
for tool in vipsheader exiftool; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "$tool is required." >&2
    exit 1
  fi
done

for file in "$@"; do
  if [[ ! -f "$file" ]]; then
    echo "File not found: $file" >&2
    exit 1
  fi
  extension="${file##*.}"
  extension="${extension,,}"
  bits="$(vipsheader -f bits-per-sample "$file")"
  header="$(vipsheader -a "$file")"
  if [[ "$header" != *"icc-profile-data"* ]]; then
    echo "$file has no embedded ICC profile." >&2
    exit 1
  fi
  if [[ "$extension" == "avif" && "$bits" -ne 10 ]]; then
    echo "$file is $bits-bit; AVIF Ultra must be 10-bit." >&2
    exit 1
  fi
  if [[ "$extension" == "jxl" && "$bits" -ne 10 ]]; then
    echo "$file is $bits-bit; JPEG XL Ultra must be 10-bit." >&2
    exit 1
  fi
  if [[ "$extension" != "avif" && "$extension" != "jxl" ]]; then
    echo "Unsupported Ultra extension: .$extension" >&2
    exit 1
  fi
  profile="$(exiftool -s -s -s -ProfileDescription "$file")"
  printf '%s: %s-bit, ICC embedded%s\n' "$file" "$bits" "${profile:+ ($profile)}"
done
