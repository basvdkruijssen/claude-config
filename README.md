# bvdk-claude-config

A durable, git-based configuration for Claude Code and Claude Desktop across
multiple machines. Memory files are per-machine, per-project, and go stale.
This repo replaces them with version-controlled skills and a global
`CLAUDE.md`, pulled fresh on every machine instead of rebuilt by hand.

## What's in here

| Piece | What | How it updates |
|---|---|---|
| `mattpocock-skills` | Engineering and productivity skills (grill-with-docs, tdd, code-review, triage, wayfinder, domain-modeling, and more) | Subscribed through Claude Code's official plugin marketplace. Auto-updates, read-only. |
| `bvdk-pstack-discipline` (this repo) | 27 writing-discipline and engineering-principle skills ported from pstack | You own it. Update by editing this repo and pushing. |
| `claude-code/CLAUDE.md` | Global Claude Code instructions | Symlinked from `~/.claude/CLAUDE.md` on each machine. |
| `claude-code/statusline-context.sh` | Status line: model, directory, git branch, context usage, and 5h/7d rate-limit usage | Symlinked from `~/.claude/statusline-context.sh`; merged into `~/.claude/settings.json` through `statusLine`. |
| `desktop-skills/` | 5 zip-ready skill bundles for Claude Desktop | Manual upload. Desktop has no marketplace mechanism (see below). |

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

### Claude Code

Three steps, the same on every machine.

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
# Windows: needs an elevated shell or Developer Mode for the symlinks
.\scripts\setup.ps1
```

**3. Done.** Restart Claude Code. The script adds this repo as a plugin
marketplace, installs `bvdk-pstack-discipline` from it, installs
`mattpocock-skills` from Claude Code's official marketplace, symlinks
`claude-code/CLAUDE.md` to `~/.claude/CLAUDE.md`, and wires up the status
line. It's safe to re-run.

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

## Options considered, not implemented

These would extend the "one repo, many machines" model further. Not added
because each needs a decision only you can make: a new dependency, an API
key, or ongoing upkeep. Listed here so you can pick one up later without
re-researching it.

- **Full dotfiles sync**, using chezmoi, GNU Stow, or rcm. Would let this same
  repo also manage `~/.claude/settings.json`, hooks, output styles, and
  non-Claude dotfiles with one tool instead of hand-rolled symlink scripts.
  Worth it if you already use one of these, or your config sprawl grows past
  `CLAUDE.md`.
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
