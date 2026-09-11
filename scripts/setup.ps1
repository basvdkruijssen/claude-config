# One-shot setup for this machine: Claude Code plugins, global CLAUDE.md,
# and the context-usage status line. Safe to re-run.
#
# Usage:
#   git clone https://github.com/basvdkruijssen/claude-config.git
#   cd claude-config
#   .\scripts\setup.ps1
#
# The symlink steps need an elevated shell or Developer Mode enabled
# (Settings > Privacy & security > For developers).
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$MarketplaceSource = "basvdkruijssen/claude-config"
$MarketplaceName = "bvdk-claude-config"

Write-Host "== 1/4: Checking for the claude CLI =="
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Error "claude not found on PATH. Install Claude Code first: https://code.claude.com"
    exit 1
}

Write-Host "== 2/4: Installing Claude Code plugins =="
claude plugin marketplace add $MarketplaceSource
claude plugin install "bvdk-pstack-discipline@$MarketplaceName"
claude plugin install mattpocock-skills

Write-Host "== 3/4: Linking global CLAUDE.md =="
$ClaudeMdSrc = Join-Path $RepoRoot "claude-code\CLAUDE.md"
$ClaudeDir = Join-Path $HOME ".claude"
$ClaudeMdDest = Join-Path $ClaudeDir "CLAUDE.md"
New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null

if ((Test-Path $ClaudeMdDest) -and -not (Get-Item $ClaudeMdDest).LinkType) {
    $ts = Get-Date -Format "yyyyMMddHHmmss"
    Write-Host "  backing up existing $ClaudeMdDest to $ClaudeMdDest.bak.$ts"
    Move-Item $ClaudeMdDest "$ClaudeMdDest.bak.$ts"
}
elseif (Test-Path $ClaudeMdDest) {
    Remove-Item $ClaudeMdDest -Force
}
New-Item -ItemType SymbolicLink -Path $ClaudeMdDest -Target $ClaudeMdSrc | Out-Null
Write-Host "  linked $ClaudeMdDest -> $ClaudeMdSrc"

Write-Host "== 4/4: Wiring up the status line =="
$StatuslineSrc = Join-Path $RepoRoot "claude-code\statusline-context.sh"
$StatuslineDest = Join-Path $ClaudeDir "statusline-context.sh"

if ((Test-Path $StatuslineDest) -and -not (Get-Item $StatuslineDest).LinkType) {
    $ts = Get-Date -Format "yyyyMMddHHmmss"
    Write-Host "  backing up existing $StatuslineDest to $StatuslineDest.bak.$ts"
    Move-Item $StatuslineDest "$StatuslineDest.bak.$ts"
}
elseif (Test-Path $StatuslineDest) {
    Remove-Item $StatuslineDest -Force
}
New-Item -ItemType SymbolicLink -Path $StatuslineDest -Target $StatuslineSrc | Out-Null
Write-Host "  linked $StatuslineDest -> $StatuslineSrc"

$SettingsPath = Join-Path $ClaudeDir "settings.json"
if (-not (Test-Path $SettingsPath)) {
    "{}" | Set-Content -Path $SettingsPath -Encoding utf8
}

# The status line always runs through a bash-compatible shell (Git Bash),
# regardless of Claude Code's configured defaultShell.
$settings = Get-Content -Path $SettingsPath -Raw | ConvertFrom-Json -AsHashtable
$settings["statusLine"] = @{
    type    = "command"
    command = "bash ~/.claude/statusline-context.sh"
}
$settings | ConvertTo-Json -Depth 20 | Set-Content -Path $SettingsPath -Encoding utf8
Write-Host "  merged statusLine into $SettingsPath"

Write-Host ""
Write-Host "Done. Restart Claude Code (exit, then run 'claude' again) to load the new plugins."
Write-Host "Then, once per project repo: run /setup-matt-pocock-skills to pick its issue tracker."
