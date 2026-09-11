#!/usr/bin/env bash
# Bootstrap this machine's Claude Code plugins from the durable config repo.
# Safe to re-run: add/install are idempotent on the Claude Code side.
set -euo pipefail

MARKETPLACE_SOURCE="basvdkruijssen/claude-config"
MARKETPLACE_NAME="bvdk-claude-config"

if ! command -v claude >/dev/null 2>&1; then
  echo "claude CLI not found on PATH. Install Claude Code first: https://code.claude.com" >&2
  exit 1
fi

echo "== Adding personal marketplace ($MARKETPLACE_SOURCE) =="
claude plugin marketplace add "$MARKETPLACE_SOURCE"

echo "== Installing bvdk-pstack-discipline (writing + engineering-principle skills) =="
claude plugin install "bvdk-pstack-discipline@${MARKETPLACE_NAME}"

echo "== Installing mattpocock-skills (official marketplace, auto-updating) =="
claude plugin install mattpocock-skills

echo "== Done. Current plugins: =="
claude plugin list
