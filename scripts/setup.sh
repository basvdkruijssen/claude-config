#!/usr/bin/env bash
# One-shot setup for this machine: Claude Code plugins, global CLAUDE.md,
# and the context-usage status line. Safe to re-run.
#
# Usage:
#   git clone https://github.com/basvdkruijssen/claude-config.git
#   cd claude-config
#   ./scripts/setup.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MARKETPLACE_SOURCE="basvdkruijssen/claude-config"
MARKETPLACE_NAME="bvdk-claude-config"

echo "== 1/4: Checking for the claude CLI =="
if ! command -v claude >/dev/null 2>&1; then
  echo "claude not found on PATH. Install Claude Code first: https://code.claude.com" >&2
  exit 1
fi

echo "== 2/4: Installing Claude Code plugins =="
claude plugin marketplace add "$MARKETPLACE_SOURCE"
claude plugin install "bvdk-pstack-discipline@${MARKETPLACE_NAME}"
claude plugin install mattpocock-skills

echo "== 3/4: Linking global CLAUDE.md =="
CLAUDE_MD_SRC="$REPO_ROOT/claude-code/CLAUDE.md"
CLAUDE_MD_DEST="$HOME/.claude/CLAUDE.md"
mkdir -p "$HOME/.claude"
if [ -e "$CLAUDE_MD_DEST" ] && [ ! -L "$CLAUDE_MD_DEST" ]; then
  ts=$(date +%Y%m%d%H%M%S)
  echo "  backing up existing $CLAUDE_MD_DEST to $CLAUDE_MD_DEST.bak.$ts"
  mv "$CLAUDE_MD_DEST" "$CLAUDE_MD_DEST.bak.$ts"
fi
ln -sf "$CLAUDE_MD_SRC" "$CLAUDE_MD_DEST"
echo "  linked $CLAUDE_MD_DEST -> $CLAUDE_MD_SRC"

echo "== 4/4: Wiring up the status line =="
STATUSLINE_SRC="$REPO_ROOT/claude-code/statusline-context.sh"
STATUSLINE_DEST="$HOME/.claude/statusline-context.sh"
if [ -e "$STATUSLINE_DEST" ] && [ ! -L "$STATUSLINE_DEST" ]; then
  ts=$(date +%Y%m%d%H%M%S)
  echo "  backing up existing $STATUSLINE_DEST to $STATUSLINE_DEST.bak.$ts"
  mv "$STATUSLINE_DEST" "$STATUSLINE_DEST.bak.$ts"
fi
ln -sf "$STATUSLINE_SRC" "$STATUSLINE_DEST"
echo "  linked $STATUSLINE_DEST -> $STATUSLINE_SRC"

SETTINGS="$HOME/.claude/settings.json"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
STATUSLINE_JSON='{"type":"command","command":"bash ~/.claude/statusline-context.sh"}'

# `command -v python3` can succeed on a broken Windows Store app-execution
# alias that errors when actually run, so verify each candidate executes
# before trusting it.
PY=""
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c "1" >/dev/null 2>&1; then
    PY="$candidate"
    break
  fi
done

if command -v jq >/dev/null 2>&1; then
  tmp=$(mktemp)
  jq --argjson sl "$STATUSLINE_JSON" '.statusLine = $sl' "$SETTINGS" > "$tmp"
  mv "$tmp" "$SETTINGS"
  echo "  merged statusLine into $SETTINGS (via jq)"
elif [ -n "$PY" ]; then
  "$PY" - "$SETTINGS" <<'PYEOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
data["statusLine"] = {"type": "command", "command": "bash ~/.claude/statusline-context.sh"}
with open(path, "w") as f:
    json.dump(data, f, indent=2)
PYEOF
  echo "  merged statusLine into $SETTINGS (via $PY)"
else
  echo "  Neither jq nor a working python found. Add this to $SETTINGS by hand:" >&2
  echo "    \"statusLine\": $STATUSLINE_JSON" >&2
fi

echo ""
echo "Done. Restart Claude Code (exit, then run 'claude' again) to load the new plugins."
echo "Then, once per project repo: run /setup-matt-pocock-skills to pick its issue tracker."
