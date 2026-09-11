#!/usr/bin/env bash
# Zip each desktop-skills/<name>/ folder so it can be uploaded to Claude Desktop
# (Settings > Features > Skills > Upload). Desktop has no marketplace mechanism,
# so this is a manual step you repeat after this repo changes.
set -euo pipefail

cd "$(dirname "$0")/.."
OUT_DIR="dist/desktop-skills"
mkdir -p "$OUT_DIR"

for dir in desktop-skills/*/; do
  name=$(basename "$dir")
  out="$OUT_DIR/${name}.zip"
  rm -f "$out"
  (cd "$dir" && zip -r -q "../../${out}" .)
  echo "Built $out"
done

echo "Upload each zip in $OUT_DIR at: Claude Desktop > Settings > Features > Skills > Upload"
