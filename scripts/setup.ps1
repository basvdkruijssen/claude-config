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

# New-Item -ItemType SymbolicLink throws when the shell lacks Developer Mode
# or elevation, unlike bash's `ln -s` on the same machine, which silently
# copies instead. Catch that and fall back to a plain copy here too, so both
# scripts behave the same way and say plainly which one happened: a copy
# needs this script re-run after every git pull; a symlink applies a pull
# automatically.
function Link-OrCopy {
    param([string]$Src, [string]$Dest)
    if ((Test-Path $Dest) -and -not (Get-Item $Dest).LinkType) {
        $ts = Get-Date -Format "yyyyMMddHHmmss"
        Write-Host "  backing up existing $Dest to $Dest.bak.$ts"
        Move-Item $Dest "$Dest.bak.$ts"
    }
    elseif (Test-Path $Dest) {
        Remove-Item $Dest -Force
    }
    try {
        New-Item -ItemType SymbolicLink -Path $Dest -Target $Src -ErrorAction Stop | Out-Null
        Write-Host "  linked $Dest -> $Src (a git pull applies future changes automatically)"
    }
    catch {
        Copy-Item -Path $Src -Destination $Dest -Force
        Write-Host "  copied $Src -> $Dest (this machine can't create symlinks without Developer Mode or an elevated shell; re-run this script after every git pull to pick up changes)"
    }
}

Write-Host "== 3/4: Linking global CLAUDE.md =="
$ClaudeDir = Join-Path $HOME ".claude"
New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
Link-OrCopy -Src (Join-Path $RepoRoot "claude-code\CLAUDE.md") -Dest (Join-Path $ClaudeDir "CLAUDE.md")

Write-Host "== 4/4: Wiring up the status line =="
Link-OrCopy -Src (Join-Path $RepoRoot "claude-code\statusline-context.sh") -Dest (Join-Path $ClaudeDir "statusline-context.sh")

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
