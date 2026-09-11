# Bootstrap this machine's Claude Code plugins from the durable config repo.
# Safe to re-run: add/install are idempotent on the Claude Code side.
$ErrorActionPreference = "Stop"

$MarketplaceSource = "basvdkruijssen/claude-config"
$MarketplaceName = "bvdk-claude-config"

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Error "claude CLI not found on PATH. Install Claude Code first: https://code.claude.com"
    exit 1
}

Write-Host "== Adding personal marketplace ($MarketplaceSource) =="
claude plugin marketplace add $MarketplaceSource

Write-Host "== Installing bvdk-pstack-discipline (writing + engineering-principle skills) =="
claude plugin install "bvdk-pstack-discipline@$MarketplaceName"

Write-Host "== Installing mattpocock-skills (official marketplace, auto-updating) =="
claude plugin install mattpocock-skills

Write-Host "== Done. Current plugins: =="
claude plugin list
