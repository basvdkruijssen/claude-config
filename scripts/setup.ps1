#Requires -Version 7
# One-shot setup for this machine: Claude Code plugins, global CLAUDE.md,
# the context-usage status line, and the Starship prompt/shell dotfiles
# (via chezmoi). Safe to re-run.
#
# Usage:
#   git clone https://github.com/basvdkruijssen/claude-config.git
#   cd claude-config
#   .\scripts\setup.ps1
#
# The symlink steps need an elevated shell or Developer Mode enabled
# (Settings > Privacy & security > For developers). Run in PowerShell 7 (pwsh);
# chezmoi is configured to run .ps1 scripts through it rather than Windows
# PowerShell 5.1.
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$MarketplaceSource = "basvdkruijssen/claude-config"
$MarketplaceName = "bvdk-claude-config"
$DotfilesSource = "github.com/basvdkruijssen/claude-config"

# Pinned Nerd Fonts release. The winget package (DEVCOM.JetBrainsMonoNerdFont)
# lags upstream Nerd Fonts releases (still on v3.3.0 as of writing) and is
# missing newer icons such as cod-claude (U+EC82, used for the Claude Code
# indicators in starship.toml). Bump this once you need a newer icon; check
# https://github.com/ryanoasis/nerd-fonts/releases first to confirm it's in there.
$NerdFontVersion = "v3.5.1"

Write-Host "== 1/7: Checking for the claude CLI =="
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Error "claude not found on PATH. Install Claude Code first: https://code.claude.com"
    exit 1
}

Write-Host "== 2/7: Installing Claude Code plugins =="
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

Write-Host "== 3/7: Linking global CLAUDE.md =="
$ClaudeDir = Join-Path $HOME ".claude"
New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
Link-OrCopy -Src (Join-Path $RepoRoot "claude-code\CLAUDE.md") -Dest (Join-Path $ClaudeDir "CLAUDE.md")

Write-Host "== 4/7: Wiring up the status line =="
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

Write-Host "== 5/7: Installing the Nerd Font (JetBrainsMono, $NerdFontVersion) =="
# Tracks which version this script last installed, since Windows has no
# reliable "is font version X installed" query of its own (InstalledFontCollection
# only gives family names, not versions) — without this, a re-run reinstalls
# every file every time, and each file triggers its own "install this font?"
# prompt (16 of them for this family). Bump $NerdFontVersion above to force a
# reinstall; delete this marker file to force one without bumping the version.
$FontMarker = Join-Path $env:LOCALAPPDATA "claude-config\nerdfont-version.txt"
if ((Test-Path $FontMarker) -and ((Get-Content $FontMarker -Raw).Trim() -eq $NerdFontVersion)) {
    Write-Host "  JetBrainsMono Nerd Font $NerdFontVersion already installed, skipping."
}
elseif (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warning "winget not found; skipping the Nerd Font install. Install 'App Installer' from the Microsoft Store and re-run this script, or install the font by hand from https://github.com/ryanoasis/nerd-fonts/releases"
}
else {
    $zipPath = Join-Path $env:TEMP "JetBrainsMono-NerdFont-$NerdFontVersion.zip"
    $extractPath = Join-Path $env:TEMP "JetBrainsMono-NerdFont-$NerdFontVersion"
    $url = "https://github.com/ryanoasis/nerd-fonts/releases/download/$NerdFontVersion/JetBrainsMono.zip"

    Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
    if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
    Expand-Archive -Path $zipPath -DestinationPath $extractPath

    # Files extracted from a downloaded zip carry the Mark-of-the-Web (Internet
    # security zone); Windows shows a "do you want to install this font?"
    # prompt per file for zone-marked fonts regardless of the CopyHere flags
    # below. Unblocking first is what actually makes the install silent.
    Get-ChildItem -Path $extractPath -Recurse -File | Unblock-File

    # Only the base family "JetBrainsMono Nerd Font" (not the Mono/Propo/NL
    # variants, which aren't used here).
    $fontFiles = Get-ChildItem -Path $extractPath -Filter "JetBrainsMonoNerdFont-*.ttf"

    # Install through the Fonts shell folder: the same path as right-click >
    # Install in Explorer. Deliberately NOT raw AddFontResource/RemoveFontResource
    # P/Invoke calls — that combination once led to an unexplained full removal
    # of the existing font installation (possibly endpoint protection flagging
    # low-level font-API manipulation as suspicious). CopyHere uses the same
    # trusted OS install path as the Explorer GUI.
    $shellFonts = (New-Object -ComObject Shell.Application).Namespace(0x14)
    foreach ($f in $fontFiles) {
        $shellFonts.CopyHere($f.FullName, 0x14)  # 0x10 = no confirmation, 0x04 = silent
    }

    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue

    New-Item -ItemType Directory -Force -Path (Split-Path $FontMarker) | Out-Null
    Set-Content -Path $FontMarker -Value $NerdFontVersion
    Write-Host "  Set 'JetBrainsMono Nerd Font' as the font in Windows Terminal / VS Code."
}

Write-Host "== 6/7: Installing Starship + chezmoi =="
winget install --id Starship.Starship --accept-package-agreements --accept-source-agreements
winget install --id twpayne.chezmoi --accept-package-agreements --accept-source-agreements

# winget's PATH update is only visible in a new shell; reload it for the rest
# of this script.
$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$env:Path = "$machinePath;$userPath"

Write-Host "== 7/7: Deploying the Starship prompt and shell dotfiles =="
# `chezmoi init <repo>` only clones into the source dir if no git repo is
# there yet; on a machine already set up from the old standalone `starship`
# repo, it silently keeps using that old remote instead of switching to this
# one. Detect that and tell the user how to fix it rather than silently
# applying stale dotfiles.
$ChezmoiSrc = Join-Path $HOME ".local\share\chezmoi"
$skipChezmoiApply = $false
if (Test-Path (Join-Path $ChezmoiSrc ".git")) {
    $currentUrl = (git -C $ChezmoiSrc remote get-url origin 2>$null)
    if ($currentUrl -and $currentUrl -notmatch "claude-config") {
        Write-Warning "chezmoi's source dir ($ChezmoiSrc) is still tracking $currentUrl, not this repo. 'chezmoi init' will NOT switch it automatically."
        Write-Host "  If $ChezmoiSrc has no changes you care about (check with: git -C `"$ChezmoiSrc`" status), fix it with:"
        Write-Host "    Remove-Item -Recurse -Force `"$ChezmoiSrc`"; .\scripts\setup.ps1"
        Write-Host "  Skipping the chezmoi apply step for now."
        $skipChezmoiApply = $true
    }
}
if (-not $skipChezmoiApply) {
    chezmoi init --apply $DotfilesSource
}

if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}
$profileLine = '. "$HOME\.config\powershell\profile.ps1"'
$existingProfile = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
if ($existingProfile -notmatch [regex]::Escape($profileLine)) {
    Add-Content $PROFILE $profileLine
    Write-Host "  added the dotfiles hook to `$PROFILE"
}
else {
    Write-Host "  `$PROFILE already has the dotfiles hook, skipping."
}

Write-Host ""
Write-Host "Done. Restart Claude Code (exit, then run 'claude' again) to load the new plugins."
Write-Host "Then, once per project repo: run /setup-matt-pocock-skills to pick its issue tracker."
Write-Host ""
Write-Host "For the prompt/shell dotfiles: run '. `$PROFILE' to pick them up in this terminal,"
Write-Host "and see docs/starship-prompt.md for day-to-day chezmoi commands and troubleshooting."
