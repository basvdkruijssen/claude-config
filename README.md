# Terminal Setup

A one-command setup for Claude Code and the terminal on macOS, Linux, WSL and
Windows. It installs a set of Claude Code plugins and skills, global Claude
Code config, and a Starship shell prompt, all kept in git so every machine
stays identical.

## What you get

- **Claude Code plugins.**
  - `bvdk-pstack-discipline` (this repo): 27 writing and engineering-principle
    skills ported from pstack.
  - `mattpocock-skills`, `claude-code-setup`, `claude-md-management`: from
    Claude Code's official marketplace.
- **Global Claude Code config.** `~/.claude/CLAUDE.md` and a status line
  showing model, directory, git branch, context usage and rate limits.
- **Terminal.** A [Starship](https://starship.rs) prompt for PowerShell 7,
  bash and zsh, a Nerd Font, and Terraform/Azure shell aliases.
- **Claude Desktop skill zips**, built from the plugin's skills.

[chezmoi](https://www.chezmoi.io) deploys everything under `~` as regular
files. No elevation, Developer Mode or symlinks needed.

## Install

Requires `git` and `curl` (macOS/Linux/WSL), or `winget`, `git` and
PowerShell 7.4+ (Windows).

```bash
git clone https://github.com/basvdkruijssen/terminal-config.git
cd terminal-config
./scripts/setup.sh          # macOS, Linux, WSL
```

```powershell
.\scripts\setup.ps1         # Windows, PowerShell 7, interactive session
```

The script installs the Claude Code CLI, the plugins, a Nerd Font (automatic on
Windows, prints the command on macOS/Linux), Starship and chezmoi. It then runs
`chezmoi init --apply`, hooks the profile into `$PROFILE` or
`.bashrc`/`.zshrc`, and adds the status line to `~/.claude/settings.json`.
It asks once for machine type (`work` or `personal`) and stores the answer
locally. Re-running is safe.

Afterwards, restart Claude Code and open a new terminal.

Optional, once per project repo: run `/setup-matt-pocock-skills` in Claude
Code to pick an issue tracker. For Jira or Azure DevOps, choose "Other".

### Claude Desktop

Desktop has no marketplace, so upload skills by hand under
Settings → Features → Skills.

```bash
./scripts/package-desktop-skills.sh    # or .ps1 on Windows
```

Upload each zip in `dist/desktop-skills/`. Repeat after any skill change.

## Use

- `unslop` runs automatically when Claude writes prose.
- The other 26 `bvdk-pstack-discipline` skills run only when you call them, for
  example `@bvdk-pstack-discipline:principle-fix-root-causes`.
- `mattpocock-skills` (`tdd`, `code-review`, `diagnosing-bugs` and others) are
  invoked by Claude as needed.

## Update

Dotfiles, global `CLAUDE.md` and status line:

```bash
chezmoi update
```

Plugins, then restart Claude Code:

```bash
claude plugin marketplace update bvdk-terminal-config
claude plugin update bvdk-pstack-discipline@bvdk-terminal-config
```

Or `git pull` and re-run the setup script, which does both. Claude Desktop
needs the zip rebuild and upload above.

Edit deployed files through chezmoi (`chezmoi edit ~/.claude/CLAUDE.md`), not
in `~`, or the next apply overwrites your change.

## More

- [`docs/starship-prompt.md`](./docs/starship-prompt.md): prompt design and chezmoi usage
- [`docs/skills.md`](./docs/skills.md): installed skills, their sources and how to update them
- [`docs/maintaining.md`](./docs/maintaining.md): adding skills, testing `setup.ps1`
- [`CLAUDE.md`](./CLAUDE.md): repo architecture and gotchas
- [`NOTICE.md`](./NOTICE.md): third-party attribution

MIT, see [`LICENSE`](./LICENSE).
