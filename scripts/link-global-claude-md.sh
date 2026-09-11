#!/usr/bin/env bash
# Symlink this repo's claude-code/CLAUDE.md to ~/.claude/CLAUDE.md so edits
# here apply on every machine after a git pull. Backs up an existing file once.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO_ROOT/claude-code/CLAUDE.md"
DEST="$HOME/.claude/CLAUDE.md"

mkdir -p "$HOME/.claude"

if [ -e "$DEST" ] && [ ! -L "$DEST" ]; then
  ts=$(date +%Y%m%d%H%M%S)
  echo "Backing up existing $DEST to $DEST.bak.$ts"
  mv "$DEST" "$DEST.bak.$ts"
fi

ln -sf "$SRC" "$DEST"
echo "Linked $DEST -> $SRC"
