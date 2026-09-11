#!/usr/bin/env bash
# One-shot setup for this machine: Claude Code plugins, global CLAUDE.md,
# the context-usage status line, and the Starship prompt/shell dotfiles
# (via chezmoi). Safe to re-run.
#
# Usage:
#   git clone https://github.com/basvdkruijssen/claude-config.git
#   cd claude-config
#   ./scripts/setup.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MARKETPLACE_SOURCE="basvdkruijssen/claude-config"
MARKETPLACE_NAME="bvdk-claude-config"
DOTFILES_SOURCE="github.com/basvdkruijssen/claude-config"

echo "== 1/7: Checking for the claude CLI =="
if ! command -v claude >/dev/null 2>&1; then
  echo "claude not found on PATH. Install Claude Code first: https://code.claude.com" >&2
  exit 1
fi

echo "== 2/7: Installing Claude Code plugins =="
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

echo "== 3/7: Linking global CLAUDE.md =="
mkdir -p "$HOME/.claude"
link_or_copy "$REPO_ROOT/claude-code/CLAUDE.md" "$HOME/.claude/CLAUDE.md"

echo "== 4/7: Wiring up the status line =="
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

echo "== 5/7: Nerd Font =="
echo "  The Starship prompt below needs a Nerd Font in your terminal emulator for"
echo "  icons to render. This isn't automated on macOS/Linux; install one, e.g.:"
echo "    brew install --cask font-jetbrains-mono-nerd-font   # macOS"
echo "  On WSL, install the font on the Windows side; the terminal emulator picks"
echo "  the font, not the Linux guest."

echo "== 6/7: Installing Starship + chezmoi =="
if ! command -v starship >/dev/null 2>&1; then
  curl -sS https://starship.rs/install.sh | sh -s -- --yes
else
  echo "  starship already installed, skipping."
fi

if ! command -v chezmoi >/dev/null 2>&1; then
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
else
  echo "  chezmoi already installed, skipping."
fi
export PATH="$HOME/.local/bin:$PATH"

echo "== 7/7: Deploying the Starship prompt and shell dotfiles =="
# `chezmoi init <repo>` only clones into the source dir if no git repo is
# there yet; on a machine already set up from the old standalone `starship`
# repo, it silently keeps using that old remote instead of switching to this
# one. Detect that and tell the user how to fix it rather than silently
# applying stale dotfiles.
CHEZMOI_SRC="$HOME/.local/share/chezmoi"
if [ -d "$CHEZMOI_SRC/.git" ]; then
  current_url=$(git -C "$CHEZMOI_SRC" remote get-url origin 2>/dev/null || true)
  case "$current_url" in
    *claude-config*|"") ;;
    *)
      echo "  WARNING: chezmoi's source dir ($CHEZMOI_SRC) is still tracking"
      echo "  $current_url, not this repo. 'chezmoi init' will NOT switch it"
      echo "  automatically. If $CHEZMOI_SRC has no changes you care about"
      echo "  (check with: git -C \"$CHEZMOI_SRC\" status), fix it with:"
      echo "    rm -rf \"$CHEZMOI_SRC\" && ./scripts/setup.sh"
      echo "  Skipping the chezmoi apply step for now."
      SKIP_CHEZMOI_APPLY=1
      ;;
  esac
fi
if [ -z "${SKIP_CHEZMOI_APPLY:-}" ]; then
  chezmoi init --apply "$DOTFILES_SOURCE"
fi

init_line='[ -f "$HOME/.config/shell/init.sh" ] && . "$HOME/.config/shell/init.sh"'
link_rc() {
  local rc_file="$1"
  [ -f "$rc_file" ] || touch "$rc_file"
  if ! grep -Fq "$init_line" "$rc_file"; then
    echo "$init_line" >> "$rc_file"
    echo "  added the dotfiles hook to $rc_file"
  else
    echo "  $rc_file already has the dotfiles hook, skipping."
  fi
}
case "$(basename "${SHELL:-bash}")" in
  zsh) link_rc "$HOME/.zshrc" ;;
  *) link_rc "$HOME/.bashrc" ;;
esac

echo ""
echo "Done. Restart Claude Code (exit, then run 'claude' again) to load the new plugins."
echo "Then, once per project repo: run /setup-matt-pocock-skills to pick its issue tracker."
echo ""
echo "For the prompt/shell dotfiles: run 'exec \"\$SHELL\" -l' to pick them up in this"
echo "terminal, and see docs/starship-prompt.md for day-to-day chezmoi commands and"
echo "troubleshooting."
