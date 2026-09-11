# bvdk-claude-config

A durable, git-based configuration for Claude Code and Claude Desktop, plus
the terminal prompt and shell dotfiles I use alongside them, across multiple
machines. Memory files are per-machine, per-project, and go stale. This repo
replaces them with version-controlled skills, a global `CLAUDE.md`, and a
[chezmoi](https://www.chezmoi.io)-managed dotfiles tree, pulled fresh on every
machine instead of rebuilt by hand.

The dotfiles half was merged in from a formerly separate, formerly-private
`starship` repo, so that one `setup.sh`/`setup.ps1` run sets up a whole new
machine. See [`docs/starship-prompt.md`](./docs/starship-prompt.md) for that
half's original README (prompt design, troubleshooting, day-to-day chezmoi
commands) and [`CLAUDE.md`](./CLAUDE.md) for the merged repo's architecture.

## What's in here

| Piece | What | How it updates |
|---|---|---|
| `mattpocock-skills` | Engineering and productivity skills (grill-with-docs, tdd, code-review, triage, wayfinder, domain-modeling, and more) | Subscribed through Claude Code's official plugin marketplace. Auto-updates, read-only. |
| `bvdk-pstack-discipline` (this repo) | 27 writing-discipline and engineering-principle skills ported from pstack | You own it. Update by editing this repo and pushing. |
| `claude-code/CLAUDE.md` | Global Claude Code instructions | Symlinked from `~/.claude/CLAUDE.md` on each machine. |
| `claude-code/statusline-context.sh` | Status line: model + reasoning effort, directory, git branch, context usage, and 5h/7d rate-limit usage | Symlinked from `~/.claude/statusline-context.sh`; merged into `~/.claude/settings.json` through `statusLine`. |
| `desktop-skills/` | 5 zip-ready skill bundles for Claude Desktop | Manual upload. Desktop has no marketplace mechanism (see below). |
| `home/` + `.chezmoiroot` | Cross-shell Starship prompt (PowerShell 7, bash, zsh), plus Terraform/Azure shell aliases | Deployed to `~` on every machine via [chezmoi](https://www.chezmoi.io), driven by `chezmoi init --apply` against this same repo. See [`docs/starship-prompt.md`](./docs/starship-prompt.md). |

## Why these two sources, and not more

You use Claude for a mix of enterprise software engineering (Jira, Azure
DevOps) and writing. Two skill collections were evaluated:

- **[mattpocock/skills](https://github.com/mattpocock/skills).** Already ships
  as an installable Claude Code plugin with an official marketplace entry.
  Its engineering skills (`triage`, `to-tickets`, `wayfinder`) default to
  GitHub, GitLab, or local-markdown trackers. Jira and Azure DevOps go through
  the "Other" freeform path in `/setup-matt-pocock-skills`, run once per
  project repo, not globally; it writes `docs/agents/issue-tracker.md` there.
  Installed whole and unmodified, through subscription.
- **[pstack](https://github.com/cursor/plugins/tree/main/pstack).** Built for
  Cursor. Its orchestration layer (`poteto-mode`, `arena`, `swarm`,
  `architect`, per-role model routing through `~/.cursor/rules/*.mdc`) doesn't
  run in Claude Code, and duplicates what Claude Code already does natively
  through its `Agent` and `Workflow` tools. Only the small, self-contained,
  Cursor-agnostic skills were ported: `unslop`, `no-comments`,
  `technical-writing`, `bro`, and the 23 `principle-*` skills. Full rationale
  and exclusion list in [`NOTICE.md`](./NOTICE.md).

## Why these two sets don't collide

Every skill ported from pstack carries `disable-model-invocation: true` in
its frontmatter. That was already true upstream, not something added here,
with one exception: `unslop` was flipped to model-invoked, because no
mattpocock skill overlaps its territory. The other 26 stay user-invoked only.
They run when you explicitly invoke them, for example
`@bvdk-pstack-discipline:principle-fix-root-causes`. mattpocock's
model-invoked skills (`tdd`, `code-review`, `diagnosing-bugs`, and others)
stay the only skills the model reaches for on its own.

There's no functional duplication either. mattpocock's `tdd` skill stays
*the* TDD skill; pstack's separate standalone `tdd` skill was excluded on
purpose (see `NOTICE.md`), so you never have two competing TDD flows
installed at once.

## Setup on a new machine

### Claude Code + terminal prompt

One script does both halves of this repo. Three steps, the same on every
machine.

**1. Clone or pull.**

```bash
git clone https://github.com/basvdkruijssen/claude-config.git
cd claude-config
# already have it? just: git pull
```

**2. Run the setup script for your OS.**

```bash
# macOS, Linux, containers
./scripts/setup.sh
```

```powershell
# Windows, PowerShell 7 (pwsh)
.\scripts\setup.ps1
```

**3. Done.** The script, in order:

1. Checks for required tools (`curl`/`git` on macOS/Linux; `winget`/`git` on
   Windows) and stops with an install hint if any are missing.
2. Installs the Claude Code CLI itself via the native installer if it isn't
   already on `PATH`, then adds this repo as a Claude Code plugin
   marketplace, installs `bvdk-pstack-discipline` from it, and installs
   `mattpocock-skills` from Claude Code's official marketplace.
3. Symlinks `claude-code/CLAUDE.md` to `~/.claude/CLAUDE.md` and
   `claude-code/statusline-context.sh` to `~/.claude/statusline-context.sh`,
   and wires the status line into `~/.claude/settings.json`.
4. Installs a Nerd Font (Windows: automatically, pinned to a recent Nerd
   Fonts release; macOS/Linux: prints the one command to run yourself, since
   that can't be automated the same way).
5. Installs Starship and chezmoi.
6. Runs `chezmoi init --apply` against this repo to deploy the prompt config,
   PowerShell profile, and shell init script to `~`, and — Windows only —
   installs the `Terminal-Icons`/`Az`/`Az.Tools.Predictor` PowerShell modules.
   You'll be prompted once for machine type (`work`/`personal`); the answer
   is stored locally, not in the repo.
7. Hooks the deployed dotfiles into `$PROFILE` (Windows) or
   `.bashrc`/`.zshrc` (macOS/Linux/WSL), if not already hooked.

It's safe to re-run. Restart Claude Code to load the new plugins, and open a
new terminal (or `. $PROFILE` / `exec "$SHELL" -l`) to pick up the prompt.

On Windows, the CLAUDE.md/status-line symlinks need Developer Mode (Settings
→ Privacy & security → For developers) or an elevated shell. Without either,
the script falls back to a plain copy and says so explicitly; a copy means
step 1's `git pull` won't reach `~/.claude` on its own, so re-run
`./scripts/setup.ps1` after every pull to apply changes. A real symlink
applies a pull automatically, with nothing further to run. This doesn't
affect the chezmoi-deployed dotfiles — chezmoi manages its own copy-vs-link
behavior independently.

For the prompt's design, day-to-day chezmoi commands (`chezmoi edit`,
`chezmoi diff`, `chezmoi update`), and troubleshooting, see
[`docs/starship-prompt.md`](./docs/starship-prompt.md).

### Testing `setup.ps1` on a fresh Windows VM

`setup.ps1` requires an actual interactive logon session (RDP or console) —
it cannot be validated headlessly, e.g. via Azure VM Run Command or a
non-interactive scheduled task. This was confirmed on both Windows Server
2022 and a Windows 11 client image:

- **Windows Server images ship without winget/App Installer at all.**
  Bootstrapping it manually (sideloading the `Microsoft.DesktopAppInstaller`
  msixbundle plus its dependencies — VCLibs, the Windows App Runtime; the
  `DesktopAppInstaller_Dependencies.zip` asset on each
  [winget-cli release](https://github.com/microsoft/winget-cli/releases)
  bundles the right versions) is possible, but `Add-AppxPackage` outright
  refuses to run under `NT AUTHORITY\SYSTEM` (`HRESULT 0x80073CF9`, "the
  Local System account is not allowed to perform this operation") — it has
  to run as a real user, e.g. via a scheduled task created with
  `schtasks /RU <user> /RP <password>`.
- **Windows 11 client images ship winget pre-provisioned**, but that doesn't
  help outside an interactive session either: `winget.exe` exists and is on
  `PATH`, but invoking it from a non-interactive context (SYSTEM, or a
  scheduled task running as a real user without an active interactive
  desktop) fails immediately with `STATUS_DLL_NOT_FOUND`
  (`0xC0000135`)/"the system cannot execute the specified program" — packaged
  (MSIX) apps need the AppModel activation infrastructure that only exists
  in a real logged-on desktop session.
- Because of the above, `setup.ps1`'s first step (`Checking dependencies`)
  reports `winget: not found` and hard-exits in both headless scenarios,
  even after winget is technically installed. Git and PowerShell 7 install
  and run fine non-interactively (they're plain downloaded installers, not
  packaged apps), so those two aren't blockers.
- The Nerd Font install step is very likely to hit the same wall for a
  different reason: it drives a `Shell.Application` COM object against the
  Explorer shell namespace, which also needs a real desktop session.

**Bottom line:** to actually test this script end-to-end on a clean VM, RDP
in and run it from an interactive PowerShell 7 session — matching what the
script's own header comment already says. Headless automation is fine for
provisioning the VM and installing baseline tooling (git, pwsh) beforehand,
but can't get past the winget check on its own.

**Migrating a machine that already ran the old standalone `starship` repo's
setup.** `chezmoi init <repo>` only clones into chezmoi's source directory
(`~/.local/share/chezmoi`) if no git repo is there yet — on such a machine
it's already a clone of `starship`, so it silently keeps using that old
remote instead of switching to this repo. The setup script detects this and
skips the chezmoi step with a warning rather than quietly applying stale
dotfiles; to fix it (once `git -C ~/.local/share/chezmoi status` is clean):

```bash
rm -rf ~/.local/share/chezmoi && ./scripts/setup.sh   # or .ps1's Remove-Item equivalent
```

Then, once per project repo, not globally:

```
/setup-matt-pocock-skills
```

Pick your issue tracker. For Jira or Azure DevOps, choose "Other" and
describe your workflow in a sentence. Then pick triage labels.

### Claude Desktop

Desktop has no plugin marketplace or git-sync mechanism. Custom skills are
zip files uploaded through Settings → Features → Skills. There's no way to
make this fully hands-off without going through Anthropic's Skills API (see
"Options considered, not implemented" below).

```bash
./scripts/package-desktop-skills.sh    # or .ps1 on Windows
```

Produces `dist/desktop-skills/*.zip`. Upload each one by hand: `unslop`,
`no-comments`, `technical-writing`, `bro`, and `engineering-principles` (the
23 principle skills bundled into one reference doc; uploading 23 near-empty
zips individually isn't practical on Desktop, so ask for a principle by name
and Claude reads it out of the bundle). mattpocock's skills aren't packaged
for Desktop; they're distributed only as a Claude Code plugin upstream.

You'll repeat the upload after any change to `desktop-skills/`. That's a
platform limitation, not a design choice.

## Maintaining this repo

- **Adding a skill.** Drop a `SKILL.md` under
  `plugins/bvdk-pstack-discipline/skills/<name>/`, bump `version` in both
  `.claude-plugin/plugin.json` and the marketplace entry, then commit and
  push. Every machine picks it up on `claude plugin update` (or reinstall).
- **Pulling upstream pstack changes.** This is a manual port, not a live
  subscription. Re-check the source files under `skills/` listed in
  `NOTICE.md` periodically and re-copy by hand if they've changed in a
  meaningful way. There's no auto-update path here by design, since
  Cursor-specific content would come along with it.
- **mattpocock-skills.** Updates on its own. Nothing to do here.
- **The Starship prompt / shell dotfiles.** Edit through chezmoi, not
  directly in `~` (`chezmoi edit ~/.config/starship.toml`, `chezmoi diff`,
  `chezmoi apply`), then `chezmoi cd` and commit/push from there. See
  [`docs/starship-prompt.md`](./docs/starship-prompt.md) and this repo's
  [`CLAUDE.md`](./CLAUDE.md) for the chezmoi-specific gotchas (notably: Nerd
  Font glyphs in `starship.toml` can silently corrupt when edited through a
  text-generation pipeline — never hand-type or LLM-edit that file directly).

## Options considered, not implemented

These would extend the "one repo, many machines" model further. Not added
because each needs a decision only you can make: a new dependency, an API
key, or ongoing upkeep. Listed here so you can pick one up later without
re-researching it.

- **Extending chezmoi's reach.** chezmoi already manages the Starship
  prompt and shell dotfiles (`home/`). It could go further and also manage
  `~/.claude/settings.json`, hooks, output styles, and other non-Claude
  dotfiles, replacing the remaining hand-rolled `Link-OrCopy`/`link_or_copy`
  symlink-or-copy logic in `scripts/setup.*` for `CLAUDE.md` and the status
  line too. Not done here to keep this merge's blast radius to "one script,
  two things it sets up" rather than restructuring already-working symlink
  logic.
- **Claude Desktop skill sync through the Skills API.** Anthropic's platform
  Skills API can create and update skills programmatically, which could
  replace the manual zip-upload step with a script run from CI or this repo.
  Needs an API key with billing attached, a bigger commitment than a local
  script.
- **Secrets-aware settings sync**, using something like the 1Password CLI or
  sops. If you later want machine-specific or credentialed Claude Code
  settings (MCP server tokens, per-org config) versioned here too, encrypt
  them rather than committing plaintext.

## License

MIT, see [`LICENSE`](./LICENSE). Third-party attribution for ported content
in [`NOTICE.md`](./NOTICE.md).
