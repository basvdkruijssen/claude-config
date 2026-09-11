#!/usr/bin/env bash
# Symlink this repo's claude-code/statusline-context.sh to ~/.claude/, and
# merge the statusLine block into ~/.claude/settings.json without touching
# any other key there (settings.json holds per-machine state like
# enabledPlugins/defaultShell, so it is never wholesale-replaced).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO_ROOT/claude-code/statusline-context.sh"
DEST_DIR="$HOME/.claude"
DEST_SCRIPT="$DEST_DIR/statusline-context.sh"
SETTINGS="$DEST_DIR/settings.json"

mkdir -p "$DEST_DIR"

if [ -e "$DEST_SCRIPT" ] && [ ! -L "$DEST_SCRIPT" ]; then
  ts=$(date +%Y%m%d%H%M%S)
  echo "Backing up existing $DEST_SCRIPT to $DEST_SCRIPT.bak.$ts"
  mv "$DEST_SCRIPT" "$DEST_SCRIPT.bak.$ts"
fi
ln -sf "$SRC" "$DEST_SCRIPT"
echo "Linked $DEST_SCRIPT -> $SRC"

if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
fi

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
else
  echo "Neither jq nor a working python found. Add this manually to $SETTINGS:" >&2
  echo '  "statusLine": '"$STATUSLINE_JSON" >&2
  exit 1
fi

echo "Merged statusLine into $SETTINGS"
echo "Restart Claude Code to see it take effect."
