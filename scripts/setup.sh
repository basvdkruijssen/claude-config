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

# Plain `ln -sf` on Git Bash for Windows never even attempts a real symlink
# unless MSYS=winsymlinks:nativestrict is set; without it, it silently
# copies the file and still reports success. With it set, a real symlink
# needs Developer Mode or an elevated shell, and fails loudly if neither is
# available. Either way, fall back to a plain copy rather than aborting the
# whole script, but say plainly which one happened: a copy needs this
# script re-run after every git pull to pick up changes; a symlink applies
# a git pull automatically.
link_or_copy() {
  local src="$1" dest="$2"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    ts=$(date +%Y%m%d%H%M%S)
    echo "  backing up existing $dest to $dest.bak.$ts"
    mv "$dest" "$dest.bak.$ts"
  fi
  if MSYS=winsymlinks:nativestrict ln -sf "$src" "$dest" 2>/dev/null && [ -L "$dest" ]; then
    echo "  linked $dest -> $src (a git pull applies future changes automatically)"
  else
    cp "$src" "$dest"
    echo "  copied $src -> $dest (this machine can't create symlinks without Developer Mode or an elevated shell; re-run this script after every git pull to pick up changes)"
  fi
}

echo "== 3/4: Linking global CLAUDE.md =="
mkdir -p "$HOME/.claude"
link_or_copy "$REPO_ROOT/claude-code/CLAUDE.md" "$HOME/.claude/CLAUDE.md"

echo "== 4/4: Wiring up the status line =="
link_or_copy "$REPO_ROOT/claude-code/statusline-context.sh" "$HOME/.claude/statusline-context.sh"

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
