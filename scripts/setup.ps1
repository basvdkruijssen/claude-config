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

$TotalSteps = 8
$script:CurrentStep = 0

# Drives both the native Write-Progress bar (rendered by the console host)
# and a plain-text banner, so output stays readable when redirected to a
# file or a non-interactive host that ignores Write-Progress.
function Step {
    param([string]$Title)
    $script:CurrentStep++
    $percent = [int](($script:CurrentStep / $TotalSteps) * 100)
    Write-Progress -Activity "claude-config setup" -Status "$Title ($script:CurrentStep/$TotalSteps)" -PercentComplete $percent
    Write-Host ""
    Write-Host "== ${script:CurrentStep}/${TotalSteps}: ${Title} =="
}

Step "Checking dependencies"
$missingDeps = @()
foreach ($dep in @("winget", "git")) {
    Write-Host "  checking for $dep..."
    $cmd = Get-Command $dep -ErrorAction SilentlyContinue
    if ($cmd) {
        Write-Host "    found: $($cmd.Source)"
    }
    else {
        Write-Host "    not found"
        $missingDeps += $dep
    }
}
if ($missingDeps.Count -gt 0) {
    Write-Error "Missing required tool(s): $($missingDeps -join ', '). Install 'App Installer' from the Microsoft Store for winget, and Git for Windows (https://git-scm.com/downloads/win) for git, then re-run this script."
    exit 1
}

Step "Checking for the claude CLI"
$claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
if ($claudeCmd) {
    Write-Host "  found: $($claudeCmd.Source)"
}
else {
    Write-Host "  claude not found on PATH. Installing via the native installer (irm https://claude.ai/install.ps1 | iex)..."
    Invoke-Expression (Invoke-RestMethod https://claude.ai/install.ps1)
    # The native installer updates PATH via the registry, which this already-
    # running process doesn't pick up on its own.
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue

    # Observed on a clean Windows machine: the installer places the binary at
    # ~/.local/bin/claude.exe but doesn't always add that directory to the
    # user PATH registry value, so the refresh above has nothing new to pick
    # up. Add it ourselves rather than fail outright.
    $installedClaude = Join-Path $HOME ".local\bin\claude.exe"
    if (-not $claudeCmd -and (Test-Path $installedClaude)) {
        Write-Host "  claude installed at $installedClaude but its directory isn't on PATH; adding it."
        $claudeBinDir = Split-Path $installedClaude -Parent
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if (($userPath -split ";") -notcontains $claudeBinDir) {
            [Environment]::SetEnvironmentVariable("Path", "$userPath;$claudeBinDir", "User")
        }
        $env:Path = "$env:Path;$claudeBinDir"
        $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    }

    if ($claudeCmd) {
        Write-Host "  installed: $($claudeCmd.Source)"
    }
    else {
        Write-Error "claude still not found on PATH after install. Open a new shell and re-run this script, or see https://code.claude.com/docs/en/troubleshoot-install"
        exit 1
    }
}

Step "Installing Claude Code plugins"
Write-Host "  adding marketplace $MarketplaceSource..."
claude plugin marketplace add $MarketplaceSource
Write-Host "  adding marketplace anthropics/claude-plugins-official (hosts mattpocock-skills)..."
claude plugin marketplace add anthropics/claude-plugins-official
Write-Host "  installing bvdk-pstack-discipline@$MarketplaceName..."
claude plugin install "bvdk-pstack-discipline@$MarketplaceName"
Write-Host "  installing mattpocock-skills..."
claude plugin install mattpocock-skills
Write-Host "  plugins installed."

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

Step "Linking global CLAUDE.md"
$ClaudeDir = Join-Path $HOME ".claude"
New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
Link-OrCopy -Src (Join-Path $RepoRoot "claude-code\CLAUDE.md") -Dest (Join-Path $ClaudeDir "CLAUDE.md")

Step "Wiring up the status line"
Link-OrCopy -Src (Join-Path $RepoRoot "claude-code\statusline-context.sh") -Dest (Join-Path $ClaudeDir "statusline-context.sh")

$SettingsPath = Join-Path $ClaudeDir "settings.json"
if (-not (Test-Path $SettingsPath)) {
    "{}" | Set-Content -Path $SettingsPath -Encoding utf8
}

# The status line always runs through a bash-compatible shell (Git Bash),
# regardless of Claude Code's configured defaultShell.
# The ?? guard covers the same AutomationNull trap as the $PROFILE hook further
# down: an existing but empty settings.json pipes nothing into ConvertFrom-Json,
# leaving $settings null and failing the index assignment on the next line.
$settingsRaw = ((Get-Content -Path $SettingsPath -Raw -ErrorAction SilentlyContinue) ?? '').Trim()
if ($settingsRaw -eq '') { $settingsRaw = '{}' }
$settings = $settingsRaw | ConvertFrom-Json -AsHashtable
$settings["statusLine"] = @{
    type    = "command"
    command = "bash ~/.claude/statusline-context.sh"
}
$settings | ConvertTo-Json -Depth 20 | Set-Content -Path $SettingsPath -Encoding utf8
Write-Host "  merged statusLine into $SettingsPath"

Step "Installing the Nerd Font (JetBrainsMono, $NerdFontVersion)"
# Tracks which version this script last installed, since Windows has no
# reliable "is font version X installed" query of its own (InstalledFontCollection
# only gives family names, not versions) — without this, a re-run reinstalls
# every file every time, and each file triggers its own "install this font?"
# prompt (16 of them for this family). Bump $NerdFontVersion above to force a
# reinstall; delete this marker file to force one without bumping the version.
$FontMarker = Join-Path $env:LOCALAPPDATA "claude-config\nerdfont-version.txt"
# ?? guards the AutomationNull trap again (see the $PROFILE hook below): a
# truncated, empty marker file would otherwise throw on .Trim() and, with
# $ErrorActionPreference = "Stop", abort the whole setup run.
$installedFontVersion = ((Get-Content $FontMarker -Raw -ErrorAction SilentlyContinue) ?? '').Trim()
if ($installedFontVersion -eq $NerdFontVersion) {
    Write-Host "  JetBrainsMono Nerd Font $NerdFontVersion already installed, skipping."
}
elseif (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warning "winget not found; skipping the Nerd Font install. Install 'App Installer' from the Microsoft Store and re-run this script, or install the font by hand from https://github.com/ryanoasis/nerd-fonts/releases"
}
else {
    $zipPath = Join-Path $env:TEMP "JetBrainsMono-NerdFont-$NerdFontVersion.zip"
    $extractPath = Join-Path $env:TEMP "JetBrainsMono-NerdFont-$NerdFontVersion"
    $url = "https://github.com/ryanoasis/nerd-fonts/releases/download/$NerdFontVersion/JetBrainsMono.zip"

    Write-Host "  downloading $url..."
    Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
    if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
    Write-Host "  extracting to $extractPath..."
    Expand-Archive -Path $zipPath -DestinationPath $extractPath

    # Files extracted from a downloaded zip carry the Mark-of-the-Web (Internet
    # security zone); Windows shows a "do you want to install this font?"
    # prompt per file for zone-marked fonts regardless of the CopyHere flags
    # below. Unblocking first is what actually makes the install silent.
    Get-ChildItem -Path $extractPath -Recurse -File | Unblock-File

    # Only the base family "JetBrainsMono Nerd Font" (not the Mono/Propo/NL
    # variants, which aren't used here).
    $fontFiles = Get-ChildItem -Path $extractPath -Filter "JetBrainsMonoNerdFont-*.ttf"
    Write-Host "  installing $($fontFiles.Count) font file(s)..."

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

Step "Installing Starship + chezmoi"
Write-Host "  installing Starship.Starship via winget..."
winget install --id Starship.Starship --accept-package-agreements --accept-source-agreements
Write-Host "  installing twpayne.chezmoi via winget..."
winget install --id twpayne.chezmoi --accept-package-agreements --accept-source-agreements

# winget's PATH update is only visible in a new shell; reload it for the rest
# of this script.
$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$env:Path = "$machinePath;$userPath"

Step "Deploying the Starship prompt and shell dotfiles"
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
    Write-Host "  running: chezmoi init --apply $DotfilesSource"
    chezmoi init --apply $DotfilesSource
    Write-Host "  dotfiles applied."
}

if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}
$profileLine = '. "$HOME\.config\powershell\profile.ps1"'
# Read the hook back with Select-String, not `Get-Content -Raw` + `-match`:
# Get-Content -Raw on an empty file — exactly what New-Item just created on a
# fresh machine — returns AutomationNull, not $null, and
# `AutomationNull -notmatch <pattern>` is an empty collection (falsy) rather than
# $true. That silently skipped the Add-Content on every fresh machine, reported
# "already has the dotfiles hook", and left PowerShell on its default prompt with
# no Starship. Casting with [string] does NOT fix it either — [string] over
# AutomationNull is $null, so .Contains() then throws. Select-String -SimpleMatch
# -Quiet returns a real Boolean for empty, missing, and populated files alike,
# and is the direct analogue of setup.sh's `grep -Fq`.
if (-not (Select-String -Path $PROFILE -SimpleMatch -Pattern $profileLine -Quiet)) {
    Add-Content $PROFILE $profileLine
    Write-Host "  added the dotfiles hook to `$PROFILE"
}
else {
    Write-Host "  `$PROFILE already has the dotfiles hook, skipping."
}

Write-Progress -Activity "claude-config setup" -Completed
Write-Host ""
Write-Host "Done. Restart Claude Code (exit, then run 'claude' again) to load the new plugins."
Write-Host "Then, once per project repo: run /setup-matt-pocock-skills to pick its issue tracker."
Write-Host ""
Write-Host "For the prompt/shell dotfiles: run '. `$PROFILE' to pick them up in this terminal,"
Write-Host "and see docs/starship-prompt.md for day-to-day chezmoi commands and troubleshooting."
