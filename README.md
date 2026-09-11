# bvdk-claude-config

A durable, git-based configuration for Claude Code and Claude Desktop across
multiple machines. The problem this solves: memory files are per-machine,
per-project, and go stale. This repo replaces that with version-controlled
skills and a global `CLAUDE.md`, pulled fresh on every machine instead of
rebuilt by hand.

## What's in here

| Piece | What | How it updates |
|---|---|---|
| `mattpocock-skills` | Engineering + productivity skills (grill-with-docs, tdd, code-review, triage, wayfinder, domain-modeling, ...) | Subscribed via Claude Code's official plugin marketplace. Auto-updates, read-only. |
| `bvdk-pstack-discipline` (this repo) | 27 writing-discipline and engineering-principle skills ported from pstack | You own it. Update by editing this repo and pushing. |
| `claude-code/CLAUDE.md` | Global Claude Code instructions | Symlinked from `~/.claude/CLAUDE.md` on each machine. |
| `claude-code/statusline-context.sh` | Bottom-left context-usage indicator (`12.5k (1.0%)`) | Symlinked from `~/.claude/statusline-context.sh`; merged into `~/.claude/settings.json` via `statusLine`. |
| `desktop-skills/` | 5 zip-ready skill bundles for Claude Desktop | Manual upload — Desktop has no marketplace mechanism (see below). |

## Why these two sources, and not more

You use Claude for a mix of enterprise software engineering (Jira/Azure
DevOps) and writing. Two skill collections were evaluated:

- **[mattpocock/skills](https://github.com/mattpocock/skills)** — already
  ships as an installable Claude Code plugin with an official marketplace
  entry. Its engineering skills (`triage`, `to-tickets`, `wayfinder`) default
  to GitHub/GitLab/local-markdown trackers; Jira/Azure DevOps go through the
  "Other" freeform path in `/setup-matt-pocock-skills` (per-repo, not global —
  run it once in each project repo, it writes `docs/agents/issue-tracker.md`
  there). Installed whole, unmodified, via subscription.
- **[pstack](https://github.com/cursor/plugins/tree/main/pstack)** — built for
  Cursor. Its orchestration layer (`poteto-mode`, `arena`, `swarm`,
  `architect`, per-role model routing via `~/.cursor/rules/*.mdc`) doesn't run
  in Claude Code and duplicates what Claude Code already does natively via its
  `Agent` and `Workflow` tools. Only the small, self-contained, Cursor-agnostic
  skills were ported: `unslop`, `no-comments`, `technical-writing`, `bro`, and
  the 23 `principle-*` skills. Full rationale and exclusion list in
  [`NOTICE.md`](./NOTICE.md).

## Why these two sets don't collide

Every skill ported from pstack carries `disable-model-invocation: true` in
its frontmatter (that was already true upstream, not something added here),
**except `unslop`**, which was deliberately flipped to model-invoked since no
mattpocock skill overlaps with its territory. The other 26 stay user-invoked
only — they run when you explicitly invoke them (e.g.
`@bvdk-pstack-discipline:principle-fix-root-causes`). mattpocock's
model-invoked skills (`tdd`, `code-review`, `diagnosing-bugs`, ...) stay the
only skills the model reaches for on its own. There's also no functional
duplication: mattpocock's `tdd` skill was kept as *the* TDD skill; pstack's
separate standalone `tdd` skill was deliberately excluded (see `NOTICE.md`)
so you never have two competing TDD flows installed at once.

## Setup on a new machine

### Claude Code

```bash
# macOS/Linux
./scripts/install-code.sh
./scripts/link-global-claude-md.sh
./scripts/link-statusline.sh
```

```powershell
# Windows
.\scripts\install-code.ps1
.\scripts\link-global-claude-md.ps1   # needs an elevated shell or Developer Mode for the symlink
.\scripts\link-statusline.ps1         # same symlink requirement
```

This adds this repo as a plugin marketplace, installs `bvdk-pstack-discipline`
from it, installs `mattpocock-skills` from Claude Code's official
marketplace, symlinks `claude-code/CLAUDE.md` to `~/.claude/CLAUDE.md`, and
wires up the context-usage status line. Re-running is safe. The status line
runs through a bash-compatible shell (Git Bash) regardless of your
`defaultShell` setting, so `statusline-context.sh` stays a `.sh` on Windows
too; the merge script only touches the `statusLine` key in `settings.json`,
every other key is left alone.

Then, **per project repo** (not global, run once per repo):

```
/setup-matt-pocock-skills
```

Pick your issue tracker (Jira/Azure DevOps → "Other", describe your workflow
in a sentence) and triage labels.

### Claude Desktop

Desktop has no plugin-marketplace or git-sync mechanism — custom skills are
zip files uploaded through Settings → Features → Skills. There's no way to
make this fully hands-off without going through Anthropic's Skills API
(see "Options considered, not implemented" below).

```bash
./scripts/package-desktop-skills.sh    # or .ps1 on Windows
```

Produces `dist/desktop-skills/*.zip`. Upload each one manually: `unslop`,
`no-comments`, `technical-writing`, `bro`, and `engineering-principles` (the
23 principle skills bundled into one reference doc — uploading 23 near-empty
zips individually isn't practical on Desktop; ask for a principle by name and
Claude reads it out of the bundle). mattpocock's skills aren't packaged for
Desktop: they're distributed only as a Claude Code plugin upstream.

You'll repeat the upload after any change to `desktop-skills/`. This is a
platform limitation, not a design choice.

## Maintaining this repo

- **Add a skill**: drop a `SKILL.md` under
  `plugins/bvdk-pstack-discipline/skills/<name>/`, bump `version` in both
  `.claude-plugin/plugin.json` and the marketplace entry, commit, push. Every
  machine picks it up on `claude plugin update` (or reinstall).
- **Pull upstream pstack changes**: this is a manual port, not a live
  subscription — re-check the source files under `skills/` listed in
  `NOTICE.md` periodically and re-copy by hand if they've changed
  meaningfully. There is no auto-update path here by design (Cursor-specific
  content would come along with it).
- **mattpocock-skills**: updates on its own; nothing to do here.

## Options considered, not implemented

These would extend the "one repo, many machines" model further. Not added
because they need a decision only you can make (a new dependency, an
API key, or ongoing upkeep) — listed here so you can pick one up later
without re-researching it.

- **Full dotfiles sync** (chezmoi, GNU Stow, rcm): would let this same repo
  also manage `~/.claude/settings.json`, hooks, output-styles, and non-Claude
  dotfiles with one tool instead of hand-rolled symlink scripts. Worth it if
  you already use one of these or your config sprawl grows past `CLAUDE.md`.
- **Claude Desktop skill sync via the Skills API**: Anthropic's platform
  Skills API can create/update skills programmatically, which could replace
  the manual zip-upload step with a script run from CI or this repo. Needs an
  API key with billing attached and is a materially bigger commitment than a
  local script.
- **Secrets-aware settings sync** (e.g. 1Password CLI, sops): if you later
  want machine-specific or credentialed Claude Code settings (MCP server
  tokens, per-org config) versioned here too, encrypt them rather than
  committing plaintext.

## License

MIT, see [`LICENSE`](./LICENSE). Third-party attribution for ported content
in [`NOTICE.md`](./NOTICE.md).
