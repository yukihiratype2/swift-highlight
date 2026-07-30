#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
upstream_path="${1:-"$project_root/.build/highlightjs"}"
output_path="$project_root/Sources/NativeHighlight/Resources/Grammars"

npm ci --prefix "$project_root/Tools"
npm ci --prefix "$upstream_path"
node "$project_root/Tools/migrate-highlightjs.cjs" \
  --upstream "$upstream_path" \
  --output "$output_path"
