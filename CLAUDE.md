# CLAUDE.md

Guidance for working on this repo (`basvdkruijssen/claude-config`), not the
global instructions it distributes (those live in `claude-code/CLAUDE.md`).

## What this repo is

Two independent halves, deployed by the same `scripts/setup.sh`/`setup.ps1`,
that happen to share one machine-setup script for convenience:

- **Claude Code/Desktop config**: `.claude-plugin/`, `plugins/`,
  `desktop-skills/`, `claude-code/` — a plugin marketplace and skill/config
  distribution mechanism. See the root `README.md` for what's in each.
- **Shell/prompt dotfiles**: `home/` plus `.chezmoiroot` at the repo root —
  a [chezmoi](https://www.chezmoi.io) source tree deploying a cross-shell
  [Starship](https://starship.rs) prompt (PowerShell 7, bash, zsh), synced to
  `~` on every machine. This half was merged in from a formerly separate,
  formerly-private `starship` repo. `.chezmoiroot` (content: `home`) tells
  chezmoi to treat `home/` as its source root, so everything else in this
  repo (`README.md`, `scripts/`, `plugins/`, ...) is invisible to it and never
  gets deployed to `~`. Full design rationale and day-to-day chezmoi usage:
  [`docs/starship-prompt.md`](./docs/starship-prompt.md) (kept in the
  original repo's language).
- There is no build step or test suite for either half — "correctness" means
  the plugin/marketplace JSON is valid, and for the dotfiles half, that the
  TOML/template files are valid and `chezmoi apply` produces the right output
  per OS.

## Validating changes to the dotfiles half (no real build/test suite — use these)

```bash
# Render/validate the prompt config directly, without touching the deployed one
STARSHIP_CONFIG="$(pwd)/home/dot_config/starship.toml" starship explain
STARSHIP_CONFIG="$(pwd)/home/dot_config/starship.toml" starship prompt

# Preview what chezmoi would change on this machine without applying it
chezmoi apply --source home -n -v      # or: chezmoi diff

# Render a .tmpl file the way chezmoi would (simulates `chezmoi init` prompts)
chezmoi execute-template --init --promptString machineType=work < path/to/file.tmpl

# Shell script syntax check
bash -n home/dot_config/shell/init.sh
bash -n scripts/setup.sh

# PowerShell syntax check (no pwsh execution needed)
pwsh -NoProfile -Command '$null = [System.Management.Automation.PSParser]::Tokenize((Get-Content -Raw "scripts/setup.ps1"), [ref]$null); "OK"'
```

## Critical gotcha: Nerd Font icons can silently go missing

Icons in `starship.toml` are Nerd Font glyphs. Two ranges behave differently
when edited through a text-generation pipeline (Write/Edit tools, or copy-paste
through an LLM):

- **Supplementary Plane glyphs** (Material Design Icons, e.g. `` U+F0000+,
  4-byte UTF-8) survive being typed/edited reliably.
- **BMP Private Use Area glyphs** (U+E000–U+F8FF — most FontAwesome/Devicons/
  Octicons glyphs, e.g. the git-branch icon, Python/​.NET devicons, clock/hourglass
  icons; 3-byte UTF-8) can silently collapse to an **empty string** with no error,
  no warning, and no visual difference in a diff viewer that can't render the glyph
  either.

This has happened for real in this repo (see git history around the "Fix lost
Nerd Font glyphs" commit) — icons for git branch, git state, .NET, Python, time,
cmd_duration, and directory substitutions all silently went blank across two
separate edits.

**After adding or changing any icon**, verify the byte-level content instead of
trusting the visual diff:

```bash
grep -n 'symbol = ""' home/dot_config/starship.toml   # catches obviously-empty ones
sed -n '<line>p' home/dot_config/starship.toml | xxd  # confirm real bytes exist
```

Prefer sourcing new icons from an authoritative output you can copy bytes from
verbatim (`starship preset <name>`, another module's already-correct symbol)
over hand-typing a glyph. If you must construct one from a codepoint, do it with
`perl -CSD` and `\x{XXXX}` escapes rather than pasting the character literally.

## Gotcha: `chezmoi init` won't repoint an already-initialized source dir

`chezmoi init <repo>` only clones `<repo>` into the source directory
(`~/.local/share/chezmoi`) when no git repo is there yet; if one already
exists — e.g. a machine previously set up from the standalone `starship` repo
this was merged from — it silently keeps that old remote and applies from it,
with no error or warning of its own. Verified by simulating both cases with
`HOME` pointed at a scratch directory. `scripts/setup.sh`/`setup.ps1` detect a
source-dir remote that doesn't match `claude-config` and skip the `chezmoi
apply` step with a warning instead of silently deploying stale dotfiles; see
the "Migrating" note in `README.md` for the fix.

## Gotcha: `Get-Content -Raw` on an empty file returns AutomationNull, not `$null`

This silently broke the PowerShell prompt on every fresh machine. `setup.ps1`
creates `$PROFILE` if it's missing, then appends the dotfiles hook only if it
isn't already there. The check was `Get-Content $PROFILE -Raw` piped into
`-notmatch`, and on the empty file `New-Item` had just created:

- `Get-Content -Raw` returns `[AutomationNull]::Value` ("no output"), **not**
  `$null` — though `$null -eq $x` on it is still `$true`, which makes it look
  like `$null` when you probe it.
- `AutomationNull -notmatch <pattern>` takes the *collection filter* path and
  returns an **empty collection** — falsy — where a literal `$null` LHS would
  have returned `$true`.

So the `if` never fired, the script printed `$PROFILE already has the dotfiles
hook, skipping.`, no hook was ever written, and PowerShell kept its default
prompt with no Starship — while `chezmoi apply`, `starship.toml` and the
Starship install were all perfectly fine, which is where the debugging time
goes.

**`[string]` does not fix it**: `[string](Get-Content emptyfile -Raw)` is
`$null`, not `""`, so a following `.Contains()` throws instead. Use one of:

```powershell
# Testing for a line in a file — the direct analogue of `grep -Fq`:
if (-not (Select-String -Path $f -SimpleMatch -Pattern $line -Quiet)) { ... }

# Needing the text itself — ?? gives a real empty string (PS7, and this repo
# already #Requires -Version 7):
$text = ((Get-Content $f -Raw -ErrorAction SilentlyContinue) ?? '').Trim()
```

All three `Get-Content -Raw` reads in `setup.ps1` (`$PROFILE`, `settings.json`,
the Nerd Font version marker) hit this; the latter two would throw under the
script's `$ErrorActionPreference = "Stop"` and abort the whole run. When adding
a new one, verify against a genuinely 0-byte file (`New-Item -ItemType File`) —
`Set-Content -Value ""` writes a newline, so the file is 2 bytes and the bug
does not reproduce:

```powershell
$f = New-Item -ItemType File "$env:TEMP\zero.txt" -Force
(Get-Content $f -Raw) -eq $null            # True — looks like $null
($null -notmatch "x")                      # True   <- what you expect
((Get-Content $f -Raw) -notmatch "x")      # empty  <- what you get
```

## Architecture

- **`.chezmoiroot`** points chezmoi's source root at `home/`, so everything
  else in this repo (`README.md`, `.gitignore`, `scripts/`, `plugins/`,
  `desktop-skills/`, `claude-code/`, `docs/`) is repo-only and never deployed
  to `~`.
- **`home/.chezmoi.toml.tmpl`** runs once at `chezmoi init`, prompting for
  `machineType` (work/personal, stored locally, not in the repo) and — on
  Windows only — configuring chezmoi to run `.ps1` scripts via `pwsh` (PS7)
  instead of Windows PowerShell 5.1.
- **`home/.chezmoiignore`** excludes `dot_config/powershell` on non-Windows and
  `dot_config/shell` on Windows. **Important:** `.chezmoiignore` does NOT apply
  to files under `.chezmoiscripts/` — a script listed there still runs on every
  OS regardless of ignore patterns.
- **OS-conditional scripts**: because ignore doesn't cover scripts, a
  Windows-only script (`home/.chezmoiscripts/run_onchange_install-psmodules.ps1.tmpl`)
  is instead a self-guarding template: its entire body is wrapped in
  `{{- if eq .chezmoi.os "windows" -}} ... {{- end -}}`. On non-Windows it
  renders to an empty string, and chezmoi skips executing a script whose
  rendered content is empty. Without the `{{ if }}` guard, Linux/WSL/macOS hit
  `fork/exec ...: exec format error` trying to run a `.ps1` file with no
  configured interpreter. Follow this same pattern for any future OS-specific
  `run_once_`/`run_onchange_` script.
- **One `starship.toml`, two shell loaders**: `home/dot_config/starship.toml`
  is shared across all platforms. `home/dot_config/powershell/profile.ps1` and
  `home/dot_config/shell/init.sh` are the platform-specific entry points that
  set `STARSHIP_CONFIG`/`$env:STARSHIP_CONFIG` and call `starship init`; they
  also carry the Terraform/Azure aliases and functions (kept in sync between
  the two — `tf`/`tfi`/`tfp`/`tfa`/`tfv`/`tff`, `azwho`/`azsw`, `cc`). Each
  loads an optional machine-local file (`profile.local.ps1` / `init.local.sh`,
  gitignored) for secrets/overrides that shouldn't be in the repo.
- **`starship.toml` structure**: built on Starship's built-in
  `catppuccin-powerline` preset as a base, with project-specific segments
  layered in (Claude Code session/repo indicators, Azure subscription,
  Terraform workspace, .NET/Python versions). All four Catppuccin palettes
  ship in the file; switch flavour by changing the single `palette = ` line.
  Two independent Claude indicators exist — `env_var.CLAUDECODE` (session is
  running inside Claude Code) and `custom.claude` (current directory has a
  `CLAUDE.md`, checked non-recursively — deliberately not `.claude/`, since
  that would also match `~` itself via the global `~/.claude` config dir).
- **`scripts/setup.ps1`/`scripts/setup.sh`** are one-time bootstrap scripts
  covering both halves of this repo: Claude Code plugin install plus
  CLAUDE.md/status-line symlinking, and (merged in from the former
  `starship` repo) Nerd Font, Starship/chezmoi install, `chezmoi init
  --apply`, and shell-profile hookup — idempotent, safe to re-run, and
  deliberately kept outside `home/` since they're not part of the deployed
  dotfiles.
