# Skills overview

Every skill this setup installs, where it comes from, and how to update it.
There are two kinds of source: skills vendored into this repo, and plugins
subscribed to from another marketplace.

| Plugin | Source | Marketplace | Vendored here? |
| --- | --- | --- | --- |
| `bvdk-pstack-discipline` | [cursor/plugins, `pstack/`](https://github.com/cursor/plugins/tree/main/pstack), ported by hand | `bvdk-terminal-config` (this repo) | Yes |
| `mattpocock-skills` | [mattpocock/skills](https://github.com/mattpocock/skills) | `claude-plugins-official` | No |
| `claude-code-setup` | Anthropic | `claude-plugins-official` | No |
| `claude-md-management` | Anthropic | `claude-plugins-official` | No |

`scripts/setup.sh` and `scripts/setup.ps1` register both marketplaces and
install all four plugins. See [`NOTICE.md`](../NOTICE.md) for licensing.

## `bvdk-pstack-discipline` (vendored)

Version 1.0.1. 27 skills and 1 agent, in
`plugins/bvdk-pstack-discipline/`. They are copied verbatim from pstack (MIT,
Lauren Tan), with no changes to the skill text.

All but `unslop` set `disable-model-invocation: true`. Claude never picks them
on its own, so they don't compete with auto-invoked skills from other plugins.
Run one by name, for example `@bvdk-pstack-discipline:principle-fix-root-causes`.

### Standalone skills

| Skill | Invocation | What it does |
| --- | --- | --- |
| `unslop` | Automatic | Cuts AI tells from any writing. |
| `technical-writing` | Manual | Layered docs standard: Diátaxis, Google developer style, STE, Global English. For docs, RFCs, readmes, PR descriptions and commit messages. |
| `no-comments` | Manual | Spawns the Comment Sicko agent, fixes accepted findings, offers encodings for claimed constraints. |
| `bro` | Manual | Restates the last message in plain language without jargon. |

### `principle-*` skills (23, all manual)

| Group | Skills |
| --- | --- |
| Debugging and root causes | `fix-root-causes`, `attack-the-premise` |
| Design and modelling | `foundational-thinking`, `model-the-domain`, `type-system-discipline`, `boundary-discipline`, `minimize-reader-load`, `exhaust-the-design-space`, `redesign-from-first-principles`, `experience-first` |
| Change and refactoring | `laziness-protocol`, `subtract-before-you-add`, `migrate-callers-then-delete-legacy-apis`, `outcome-oriented-execution`, `make-operations-idempotent` |
| Verification and testing | `prove-it-works`, `test-behavior-not-implementation`, `sequence-verifiable-units` |
| Delegation and process | `build-the-lever`, `encode-lessons-in-structure`, `guard-the-context-window`, `never-block-on-the-human`, `separate-before-serializing-shared-state` |

Each skill's trigger lives in its own `description`. Read
`plugins/bvdk-pstack-discipline/skills/<name>/SKILL.md` for the full text.

### Agent

`comment-sicko` (`agents/comment-sicko.md`) hunts comments in a scope or diff
and flags workaround code for removal. The `no-comments` skill drives it. It
never edits application code.

### Not ported

Cursor-specific pstack skills (`poteto-mode`, `arena`, `swarm`, `setup-pstack`
and others) and pstack's standalone `tdd` are left out on purpose. The reasons
are in [`NOTICE.md`](../NOTICE.md).

### Updating

Skill text changes in this repo:

1. Edit or add `plugins/bvdk-pstack-discipline/skills/<name>/SKILL.md`.
2. Bump `version` in both `plugins/bvdk-pstack-discipline/.claude-plugin/plugin.json`
   and the entry in `.claude-plugin/marketplace.json`. Claude Code only sees a
   new version when these change.
3. Commit and push.
4. On each machine, then restart Claude Code:

   ```bash
   claude plugin marketplace update bvdk-terminal-config
   claude plugin update bvdk-pstack-discipline@bvdk-terminal-config
   ```

   Re-running `scripts/setup.*` after a `git pull` does the same.

Upstream pstack changes: there is no automatic sync. Compare the files listed in
`NOTICE.md` against upstream now and then, and re-copy by hand when a change is
meaningful. Then follow the steps above.

Claude Desktop: it has no marketplace, so rebuild and re-upload the zips after
any skill change.

```bash
./scripts/package-desktop-skills.sh    # .ps1 on Windows
```

The four standalone skills each get a zip. The 23 principles are bundled into
one `engineering-principles` zip. A new standalone skill must be added to the
`STANDALONE` list in both scripts. A new `principle-*` skill is picked up
automatically. Upload the zips from `dist/desktop-skills/` under Settings →
Features → Skills.

## `mattpocock-skills` (subscribed)

Matt Pocock's engineering skills, installed from the official marketplace
(`claude-plugins-official`). Installed version at time of writing: 1.2.3.
Nothing is copied into this repo, so upstream owns the content and this repo
has no control over it. Claude invokes these on its own when a task matches.

Skills you will see most often:

| Skill | Use |
| --- | --- |
| `tdd` | Test-first development, red-green-refactor |
| `diagnosing-bugs` | Diagnosis loop for hard bugs and performance regressions |
| `code-review` | Review changes since a commit or branch against repo standards and the originating spec |
| `grilling` | Stress-test a plan or decision with relentless questions |
| `domain-modeling` | Build the domain model, `CONTEXT.md` and ADRs |
| `codebase-design` | Deep-module vocabulary for interface and seam design |
| `prototype` | Throwaway prototype to answer a design question |
| `research` | Investigate a question against primary sources into a Markdown file |
| `resolving-merge-conflicts` | Resolve an in-progress merge or rebase conflict |
| `wizard` | Generate an interactive bash wizard for human-only steps |
| `writing-for-agents` | Write or edit skills, `AGENTS.md` and `CLAUDE.md` |

The plugin ships more than this. Type `/` in Claude Code to see everything
currently available. Run `/setup-matt-pocock-skills` once per project repo to
pick an issue tracker. For Jira or Azure DevOps, choose "Other".

### Updating

```bash
claude plugin marketplace update claude-plugins-official
claude plugin update mattpocock-skills@claude-plugins-official
```

Restart Claude Code afterwards.

## `claude-code-setup` and `claude-md-management` (subscribed)

Both come from Anthropic's official marketplace and are not vendored.

| Plugin | Skill | Use |
| --- | --- | --- |
| `claude-code-setup` | `claude-automation-recommender` | Recommends hooks, subagents, skills, plugins and MCP servers for a codebase |
| `claude-md-management` | `claude-md-improver` | Audits and improves `CLAUDE.md` files |
| `claude-md-management` | `revise-claude-md` | Updates `CLAUDE.md` with learnings from the current session |

### Updating

```bash
claude plugin marketplace update claude-plugins-official
claude plugin update claude-code-setup@claude-plugins-official
claude plugin update claude-md-management@claude-plugins-official
```

## Checking what is installed

```bash
claude plugin list                  # installed plugins, versions, enabled state
claude plugin marketplace list      # registered marketplaces
```

If a plugin doesn't show a new version after an update, run
`claude plugin marketplace update <marketplace>` first, since the version
check reads the marketplace's cached copy.

## Adding a new source

- **Your own skill:** add it under `plugins/bvdk-pstack-discipline/skills/` and
  follow the update steps above. See [`maintaining.md`](./maintaining.md).
- **Someone else's plugin:** subscribe instead of copying where an upstream
  marketplace exists. Add the install line to `scripts/setup.sh` and
  `scripts/setup.ps1`, list it in the table at the top of this page and in the
  root `README.md`.
- **Something you vendor:** add attribution and the source files to
  [`NOTICE.md`](../NOTICE.md), so the next upstream check knows what to compare.
