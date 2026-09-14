<!--
This file is the README of the formerly standalone `basvdkruijssen/starship`
repo, folded into this one under `home/` and translated to English since. The
install steps are automated by this repo's `scripts/setup.sh`/`setup.ps1`
(they run `chezmoi init --apply` against this repo, not the old standalone
one); read this file for the "why" behind the prompt design, troubleshooting,
and day-to-day chezmoi commands, not for setup steps.
-->

# Starship prompt

Cross-shell terminal prompt built on [Starship](https://starship.rs), geared
towards working with **Azure**, **Terraform** and **Claude Code**. One config
drives PowerShell 7, bash and zsh, deployed to multiple machines with
[chezmoi](https://www.chezmoi.io).

It replaces the loose gists (`Microsoft.PowerShell_profile.ps1`,
`ohmyposh.omp.json`, `terminal-setup.txt`) with a single version-controlled
source.

## What the prompt shows

Based on Starship's built-in [`catppuccin-powerline`
preset](https://starship.rs/presets/#catppuccin-powerline) in the **Mocha**
flavour (`starship preset catppuccin-powerline`), with the project-specific
segments added back. Every segment has its own icon so you can tell at a glance
which part of the prompt comes from which source. The prompt character sits on
its own line below the rest, so typed input never lands next to a long status
line.

| Icon | Segment | Source | Shown when |
| --- | --- | --- | --- |
|  | local time | system clock | always, first segment (lavender block) |
|  | `claude-code` | `$CLAUDECODE` | the shell runs inside a Claude Code session |
| 󰉋 | path | working directory | always, truncated to the repo root (peach block) |
|  | branch | git | in a git repo (yellow block) |
|  | merge/rebase state | git | during a merge, rebase, revert, ... (yellow block) |
| ⇡⇣!+?... | git status | git | built-in glyphs per state: ahead/behind/modified/staged/... (yellow block) |
|  | .NET version | `.csproj` and the like | in a .NET project (green block) |
|  | Python version | `.py`, `venv`, ... | in a Python project (green block) |
|  | `claude` | `CLAUDE.md` | the repo has a `CLAUDE.md` (not `.claude/`, which would also fire in `~`) |
| 󰠅 | `plat-prd as user@company.com` | `az account show` | Azure CLI is logged in; shows subscription + signed-in user |
| 󱁢 | `default` | Terraform workspace | `.tf` files or `.terraform/` present |
|  | `took 4s` | previous command | the command took longer than 2 seconds |
| ❯ / ❮ | prompt character | shell mode | on its own line below the rest; ❮ in vim mode |

Kubernetes, AWS, GCP, Node, Rust, Go and package versions are off to limit
noise; `$os`/`$username` from the preset are left out on purpose (personal dev
machine, no added value). Want another flavour? Set `palette` in
`starship.toml` to `catppuccin_latte`, `catppuccin_frappe` or
`catppuccin_macchiato`; all four are already in the file.

## What the repo manages

| File in the repo | Target path | Platform |
| --- | --- | --- |
| `home/dot_config/starship.toml` | `~/.config/starship.toml` | all |
| `home/dot_config/powershell/profile.ps1` | `~/.config/powershell/profile.ps1` | Windows |
| `home/dot_config/shell/init.sh` | `~/.config/shell/init.sh` | Linux, WSL, macOS |
| `home/.chezmoiscripts/run_onchange_install-psmodules.ps1.tmpl` | installs Terminal-Icons, Az, Az.Tools.Predictor | Windows |
| `home/dot_claude/CLAUDE.md` | `~/.claude/CLAUDE.md` (global Claude Code instructions) | all |
| `home/dot_claude/statusline-context.sh` | `~/.claude/statusline-context.sh` (Claude Code status line) | all |

The two `~/.claude` files belong to the Claude Code half of the repo but are
deliberately deployed through chezmoi: one mechanism for everything in `~`, no
symlinks, so no Developer Mode or elevated shell is needed on managed corporate
devices. `~/.claude/settings.json` is *not* managed by chezmoi (Claude Code
writes that file itself); `scripts/setup.*` only merge the `statusLine` key
into it.

Still to add (contents are machine-bound, see
[Adding existing settings](#adding-existing-settings)): Windows Terminal
`settings.json` and optionally VS Code `settings.json`.

## Structure

```
.
├── .chezmoiroot                     # points chezmoi's source root at home/
├── scripts/
│   ├── setup.ps1                    # automated install, Windows
│   └── setup.sh                     # automated install, Linux/WSL/macOS
├── docs/starship-prompt.md          # this file
├── ...                              # Claude Code plugin and config, see root README
└── home/                            # everything below is deployed to ~
    ├── .chezmoi.toml.tmpl           # machine-specific values + ps1 interpreter
    ├── .chezmoiignore               # excludes PowerShell on Linux and vice versa
    ├── .chezmoiscripts/             # scripts, not deployed themselves
    │   └── run_onchange_install-psmodules.ps1.tmpl
    ├── dot_claude/                  # -> ~/.claude/ (only these two files)
    │   ├── CLAUDE.md
    │   └── statusline-context.sh
    └── dot_config/
        ├── starship.toml
        ├── powershell/profile.ps1
        └── shell/init.sh
```

chezmoi turns `dot_` into a leading dot on deploy. Thanks to `.chezmoiroot`,
everything outside `home/` (README, scripts, the Claude Code plugin) stays out
of the deployment.

---

## Installing on a new machine

Automated by `scripts/setup.sh` (Linux, WSL, macOS) and `scripts/setup.ps1`
(Windows, PowerShell 7) in the root of this repo: they install the Nerd Font
(Windows) or tell you how (macOS/Linux), install Starship and chezmoi, run
`chezmoi init --apply` against this repo and hook `$PROFILE` or
`.bashrc`/`.zshrc`. The steps are listed in the
[root README](../README.md#setup-on-a-new-machine); the repo is public, so no
`gh auth` is needed.

Do **not** use `chezmoi init github.com/basvdkruijssen/starship` anymore: that
repo was merged into this one. If chezmoi's source directory on a machine still
points at that old remote, the setup script warns and skips the apply step; see
"Migrating" in the root README for the fix.

By hand, after the scripts: set `JetBrainsMono Nerd Font` as the font in
Windows Terminal (Settings → Profiles → Defaults → Appearance → Font face) and
optionally VS Code (`terminal.integrated.fontFamily`). The winget package
`DEVCOM.JetBrainsMonoNerdFont` lags upstream and lacks the `cod-claude` icon
(U+EC82); `setup.ps1` therefore installs a pinned release straight from
[Nerd Fonts](https://github.com/ryanoasis/nerd-fonts/releases).

---

## Migrating from the previous setup

On machines that still have the old Oh My Posh profile:

```powershell
# 1. Keep the old profile. Use $PROFILE, not a fixed Documents path: on corporate
#    devices with OneDrive Known Folder Move, Documents lives under OneDrive.
$old = $PROFILE
Copy-Item $old "$old.bak" -Force

# 2. Replace it with a reference to the repo version
Set-Content $old '. "$HOME\.config\powershell\profile.ps1"'

# 3. Check whether $old.bak still holds anything the repo doesn't;
#    machine-specific bits go to ~/.config/powershell/profile.local.ps1
```

Carried over from the old profile: Terminal-Icons, the PSReadLine settings, the
winget and az completers, Az.Tools.Predictor and the early `return` for
non-interactive sessions. Two changes:

- Oh My Posh is replaced by Starship. `ohmyposh.omp.json` is no longer needed;
  keep the gist as an archive or delete it.
- `PredictionSource` is `HistoryAndPlugin` instead of `History`, otherwise
  Az.Tools.Predictor produces no suggestions.

### Adding existing settings

Add these once on your main machine; afterwards they roll out to the rest.

```powershell
# Windows Terminal
chezmoi add "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

# VS Code (optional)
chezmoi add "$env:APPDATA\Code\User\settings.json"

chezmoi cd
git add -A ; git commit -m "Add Windows Terminal and VS Code settings" ; git push
exit
```

If you use the unpackaged Windows Terminal rather than the Store version, the
path is `$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json`.

After adding, check `settings.json` for things that don't belong in a repo,
such as local user names in `startingDirectory` or `commandline`. If needed,
turn it into a `.tmpl` and replace them with `{{ .chezmoi.homeDir }}`.

---

## Making changes

Always edit through chezmoi, never directly in `~`, or the repo and the machine
drift apart.

```bash
chezmoi edit ~/.config/starship.toml   # edit the source
chezmoi diff                           # see what would change
chezmoi apply                          # apply on this machine
chezmoi cd                             # go to the repo
git commit -am "Prompt: adjust segment X" && git push
exit
```

On the other machines:

```bash
chezmoi update                         # pull + apply in one step
```

---

## Adapting to your own environment

**Azure subscription aliases.** The keys in `[azure.subscription_aliases]` in
`home/dot_config/starship.toml` must match the output of
`az account list -o table` exactly. The values shipped are examples; if they
don't match, the prompt shows the full, long subscription name.

**Machine-specific additions.** Put client-specific functions, paths or tokens
in `~/.config/powershell/profile.local.ps1` or `~/.config/shell/init.local.sh`.
Both are loaded automatically when present and are gitignored.

**Per-machine differences in the config itself.** Rename `starship.toml` to
`starship.toml.tmpl` and use the variable from `.chezmoi.toml.tmpl`:

```toml
{{ if eq .machineType "work" }}
[azure]
disabled = false
{{ end }}
```

**Slimming down the Az module.** The full `Az` module is about 1 GB. In
`run_onchange_install-psmodules.ps1.tmpl`, replace it with only what you use,
for example `Az.Accounts` and `Az.Resources`.

**Performance.** No segment spawns a subprocess: `[custom.claude]` only checks
for a file and prints literal text (it used to run `echo claude`, which cost
about 500 ms per prompt on Windows), and `[env_var.CLAUDECODE]` is free. The
Terraform version is deliberately not shown because `terraform version` is too
slow to run on every prompt.

---

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| Empty boxes or question marks | Nerd Font not set in the terminal emulator |
| Prompt unchanged after install | `$PROFILE` or `~/.bashrc` not hooked; re-run the setup script, which adds the hook when it is missing |
| Two prompts or double init | Old Oh My Posh profile still present; see Migrating |
| No Azure segment | Not logged in: `az login` |
| Full, long subscription name | Alias key doesn't exactly match `az account list -o table` |
| Modules not installed | Script runs on Windows only; force with `chezmoi apply --force` |
| `chezmoi apply` overwrites nothing | File edited by hand; resolve with `chezmoi merge <path>` |
| `Username for 'https://github.com'` during `chezmoi init` | Only with a private fork: git credential helper not hooked to `gh`; run `gh auth setup-git` (per environment, WSL counts separately from Windows) |
| `fork/exec ...install-psmodules.ps1: exec format error` on Linux/WSL/macOS | Stale source state from before the fix (`.chezmoiignore` doesn't exclude scripts, so the `.ps1` script had to become a self-guarding `.tmpl`). Fix with `chezmoi update` |
