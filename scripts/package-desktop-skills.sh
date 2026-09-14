#!/usr/bin/env bash
# Build the Claude Desktop skill zips from the Claude Code plugin's skills, so
# plugins/bvdk-pstack-discipline/skills/ stays the single source of truth: the
# four standalone skills are copied as-is, and the principle-* skills are
# bundled into one engineering-principles skill (Desktop skills are uploaded one
# zip at a time; 23 near-empty zips isn't practical). Upload the zips by hand at
# Claude Desktop > Settings > Features > Skills > Upload. Desktop has no
# marketplace or git-sync mechanism, so repeat this after the skills change.
#
# scripts/package-desktop-skills.ps1 is the Windows twin and produces the same
# bytes; keep the two in sync.
set -euo pipefail

cd "$(dirname "$0")/.."
SKILLS_DIR="plugins/bvdk-pstack-discipline/skills"
OUT_DIR="dist/desktop-skills"
STANDALONE=(unslop no-comments technical-writing bro)

if ! command -v zip >/dev/null 2>&1; then
  echo "zip not found. Install it, or on Windows run scripts/package-desktop-skills.ps1 instead." >&2
  exit 1
fi

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

# Everything below the frontmatter, LF line endings, no leading/trailing blank lines.
skill_body() {
  tr -d '\r' < "$1" | awk '
    /^---$/ && fm < 2 { fm++; next }
    fm < 2 { next }
    { lines[++n] = $0 }
    END {
      s = 1; while (s <= n && lines[s] == "") s++
      e = n; while (e >= s && lines[e] == "") e--
      for (i = s; i <= e; i++) print lines[i]
    }'
}

for name in "${STANDALONE[@]}"; do
  mkdir -p "$OUT_DIR/$name"
  tr -d '\r' < "$SKILLS_DIR/$name/SKILL.md" > "$OUT_DIR/$name/SKILL.md"
done

principles=("$SKILLS_DIR"/principle-*/SKILL.md)
count=${#principles[@]}
bundle="$OUT_DIR/engineering-principles/SKILL.md"
mkdir -p "$(dirname "$bundle")"
{
  cat <<HEADER
---
name: engineering-principles
description: Reference index of $count engineering principles (core design, architecture, verification, delegation, meta) ported from pstack. Ask to apply one by name, e.g. "apply the fix-root-causes principle here".
---

# Engineering principles

$count short rules. Ported from pstack (cursor/plugins), MIT licensed, see NOTICE.md in the source repo. Each is its own skill in the Claude Code plugin; bundled into one document here because Claude Desktop skills are uploaded as individual zips and $count near-empty zips isn't practical. Ask for one by name.
HEADER
  for f in "${principles[@]}"; do
    printf '\n---\n\n'
    # Cross-links between principles point at sibling skill folders in the
    # plugin; inside one document they become heading anchors.
    skill_body "$f" | sed -E 's|\]\(\.\./principle-([a-z0-9-]+)/SKILL\.md\)|](#\1)|g'
  done
} > "$bundle"

for dir in "$OUT_DIR"/*/; do
  name=$(basename "$dir")
  (cd "$dir" && zip -r -q "../$name.zip" .)
  echo "Built $OUT_DIR/$name.zip"
done

echo "Upload each zip in $OUT_DIR at: Claude Desktop > Settings > Features > Skills > Upload"
