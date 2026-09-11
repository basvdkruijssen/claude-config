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

TOTAL_STEPS=8
CURRENT_STEP=0

# Prints a "[#####-----] 3/8" bar, then the step title as a banner. Kept as a
# plain ASCII bar (rather than e.g. a spinner) since this script's output is
# also read back from CI logs and piped output, where cursor control codes
# would just show up as garbage.
progress_bar() {
  local step="$1" total="$2" width=30
  local filled=$(( step * width / total ))
  local empty=$(( width - filled ))
  local bar
  bar="$(printf '%*s' "$filled" '' | tr ' ' '#')"
  bar+="$(printf '%*s' "$empty" '' | tr ' ' '-')"
  printf '\n[%s] %d/%d\n' "$bar" "$step" "$total"
}

step() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  progress_bar "$CURRENT_STEP" "$TOTAL_STEPS"
  echo "== $CURRENT_STEP/$TOTAL_STEPS: $1 =="
}

step "Checking dependencies"
missing_deps=()
for dep in curl git; do
  echo "  checking for $dep..."
  if command -v "$dep" >/dev/null 2>&1; then
    echo "    found: $(command -v "$dep")"
  else
    echo "    not found"
    missing_deps+=("$dep")
  fi
done
if [ "${#missing_deps[@]}" -gt 0 ]; then
  echo "Missing required tool(s): ${missing_deps[*]}" >&2
  echo "Install them first, e.g. on Debian/Ubuntu: sudo apt install ${missing_deps[*]}" >&2
  echo "On Alpine: apk add ${missing_deps[*]}" >&2
  exit 1
fi

step "Checking for the claude CLI"
if command -v claude >/dev/null 2>&1; then
  echo "  found: $(command -v claude) ($(claude --version 2>/dev/null || echo "version unknown"))"
else
  echo "  claude not found on PATH. Installing via the native installer (curl -fsSL https://claude.ai/install.sh | bash)..."
  curl -fsSL https://claude.ai/install.sh | bash
  # The native installer places the launcher in ~/.local/bin, which may not
  # be on PATH yet in this shell (it takes effect for new shells once the
  # installer's rc-file edit is sourced).
  export PATH="$HOME/.local/bin:$PATH"
  if command -v claude >/dev/null 2>&1; then
    echo "  installed: $(command -v claude)"
  else
    echo "claude still not found on PATH after install. Open a new shell and re-run this script, or see https://code.claude.com/docs/en/troubleshoot-install" >&2
    exit 1
  fi
fi

step "Installing Claude Code plugins"
echo "  adding marketplace $MARKETPLACE_SOURCE..."
claude plugin marketplace add "$MARKETPLACE_SOURCE"
echo "  adding marketplace anthropics/claude-plugins-official (hosts mattpocock-skills)..."
claude plugin marketplace add anthropics/claude-plugins-official
echo "  installing bvdk-pstack-discipline@${MARKETPLACE_NAME}..."
claude plugin install "bvdk-pstack-discipline@${MARKETPLACE_NAME}"
echo "  installing mattpocock-skills..."
claude plugin install mattpocock-skills
echo "  plugins installed."

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

step "Linking global CLAUDE.md"
mkdir -p "$HOME/.claude"
link_or_copy "$REPO_ROOT/claude-code/CLAUDE.md" "$HOME/.claude/CLAUDE.md"

step "Wiring up the status line"
link_or_copy "$REPO_ROOT/claude-code/statusline-context.sh" "$HOME/.claude/statusline-context.sh"

SETTINGS="$HOME/.claude/settings.json"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
STATUSLINE_JSON='{"type":"command","command":"bash ~/.claude/statusline-context.sh"}'

# `command -v python3` can succeed on a broken Windows Store app-execution
# alias that errors when actually run, so verify each candidate executes
# before trusting it.
echo "  looking for jq or python to merge $SETTINGS..."
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

step "Nerd Font"
echo "  The Starship prompt below needs a Nerd Font in your terminal emulator for"
echo "  icons to render. This isn't automated on macOS/Linux; install one, e.g.:"
echo "    brew install --cask font-jetbrains-mono-nerd-font   # macOS"
echo "  On WSL, install the font on the Windows side; the terminal emulator picks"
echo "  the font, not the Linux guest."

step "Installing Starship + chezmoi"
if command -v starship >/dev/null 2>&1; then
  echo "  starship already installed, skipping: $(command -v starship)"
else
  echo "  installing starship (curl -sS https://starship.rs/install.sh | sh)..."
  curl -sS https://starship.rs/install.sh | sh -s -- --yes
  echo "  starship installed."
fi

if command -v chezmoi >/dev/null 2>&1; then
  echo "  chezmoi already installed, skipping: $(command -v chezmoi)"
else
  echo "  installing chezmoi (curl -fsLS get.chezmoi.io | sh)..."
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
  echo "  chezmoi installed to $HOME/.local/bin."
fi
export PATH="$HOME/.local/bin:$PATH"

step "Deploying the Starship prompt and shell dotfiles"
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
  echo "  running: chezmoi init --apply $DOTFILES_SOURCE"
  chezmoi init --apply "$DOTFILES_SOURCE"
  echo "  dotfiles applied."
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

progress_bar "$TOTAL_STEPS" "$TOTAL_STEPS"
echo ""
echo "Done. Restart Claude Code (exit, then run 'claude' again) to load the new plugins."
echo "Then, once per project repo: run /setup-matt-pocock-skills to pick its issue tracker."
echo ""
echo "For the prompt/shell dotfiles: run 'exec \"\$SHELL\" -l' to pick them up in this"
echo "terminal, and see docs/starship-prompt.md for day-to-day chezmoi commands and"
echo "troubleshooting."
