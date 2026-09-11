---
title: Third-party attribution
---

# Third-party attribution

This repo ports a small subset of two upstream skill collections. Both are
MIT-licensed; both are reproduced here with attribution as required by that
license.

## pstack

Source: [cursor/plugins, `pstack/` directory](https://github.com/cursor/plugins/tree/main/pstack)
Author: Lauren Tan ([@poteto](https://x.com/poteto))
License: MIT

`plugins/bvdk-pstack-discipline/skills/unslop`, `no-comments`,
`technical-writing`, `bro`, all 23 `principle-*` skills, and
`plugins/bvdk-pstack-discipline/agents/comment-sicko.md` are copied verbatim
from this source. Nothing else from pstack is included here.

**Deliberately not ported**, and why:

- `poteto-mode`, `arena`, `swarm`, `architect`, `interrogate`, `how`, `why`,
  `recall`, `reflect`, `automate-me`, `make-bot-ui`, `swarm`, `teach`,
  `show-me-your-work`, `figure-it-out`, `create-verification-skill`,
  `maintain-verification-skill`, `typescript-best-practices`, and the
  standalone `tdd` skill: these depend on Cursor-specific mechanics
  (`.cursor/rules/*.mdc`, `/add-plugin`, Cursor's `/loop`, Cursor model slugs
  like `grok-4.6-fast-xhigh` / `gpt-5.6-sol-max`, and Cursor's own Task/agent
  routing) or duplicate what Claude Code already provides natively (parallel
  subagents via the `Agent` tool, multi-stage orchestration via `Workflow`).
  Porting them would mean maintaining a second, competing orchestration layer.
- `setup-pstack`: writes Cursor model-routing config; meaningless outside
  Cursor.
- The standalone `tdd` skill: mattpocock's `tdd` skill already covers this
  ground and is the one installed here (see below); keeping both would give
  two skills the same job.

## mattpocock/skills

Source: [mattpocock/skills](https://github.com/mattpocock/skills)
Author: Matt Pocock
License: MIT

**Not vendored here.** Per your own choice, this is installed as a live
subscription to Matt's official Claude Code plugin marketplace
(`claude plugin install mattpocock-skills`), not copied into this repo. It
auto-updates from upstream; this repo has no control over or copy of its
content. See `README.md` for the install step.
