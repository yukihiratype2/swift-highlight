#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${1:?usage: package-release.sh VERSION [OUTPUT_DIRECTORY]}"
output_path="${2:-"$project_root/dist"}"
grammar_path="$project_root/Sources/NativeHighlight/Resources/Grammars"

test -f "$grammar_path/catalog.json" || {
  echo "Generated grammars are missing; run Scripts/generate-grammars.sh first." >&2
  exit 1
}

work_path="$(mktemp -d)"
trap 'rm -rf "$work_path"' EXIT
package_name="NativeHighlight-$version"
package_path="$work_path/$package_name"

mkdir -p "$package_path" "$output_path"
git -C "$project_root" archive HEAD | tar -x -C "$package_path"
mkdir -p "$package_path/Sources/NativeHighlight/Resources"
cp -R "$grammar_path" "$package_path/Sources/NativeHighlight/Resources/Grammars"

tar -czf "$output_path/$package_name.tar.gz" -C "$work_path" "$package_name"
(
  cd "$work_path"
  zip -qr "$output_path/$package_name.zip" "$package_name"
)
tar -czf "$output_path/NativeHighlight-Grammars-$version.tar.gz" \
  -C "$project_root/Sources/NativeHighlight/Resources" Grammars

(
  cd "$output_path"
  sha256sum \
    "$package_name.tar.gz" \
    "$package_name.zip" \
    "NativeHighlight-Grammars-$version.tar.gz" > SHA256SUMS
)
