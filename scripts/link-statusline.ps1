# Symlink this repo's claude-code\statusline-context.sh to ~/.claude/, and
# merge the statusLine block into ~/.claude/settings.json without touching
# any other key there (settings.json holds per-machine state like
# enabledPlugins/defaultShell, so it is never wholesale-replaced).
# Creating the symlink normally needs an elevated shell or Developer Mode
# enabled (Settings > Privacy & security > For developers). The statusLine
# command itself always runs through a bash-compatible shell (Git Bash),
# regardless of defaultShell, so the script stays a .sh even on Windows.
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Src = Join-Path $RepoRoot "claude-code\statusline-context.sh"
$DestDir = Join-Path $HOME ".claude"
$DestScript = Join-Path $DestDir "statusline-context.sh"
$SettingsPath = Join-Path $DestDir "settings.json"

New-Item -ItemType Directory -Force -Path $DestDir | Out-Null

if ((Test-Path $DestScript) -and -not (Get-Item $DestScript).LinkType) {
    $ts = Get-Date -Format "yyyyMMddHHmmss"
    Write-Host "Backing up existing $DestScript to $DestScript.bak.$ts"
    Move-Item $DestScript "$DestScript.bak.$ts"
}
elseif (Test-Path $DestScript) {
    Remove-Item $DestScript -Force
}
New-Item -ItemType SymbolicLink -Path $DestScript -Target $Src | Out-Null
Write-Host "Linked $DestScript -> $Src"

if (-not (Test-Path $SettingsPath)) {
    "{}" | Set-Content -Path $SettingsPath -Encoding utf8
}

$settings = Get-Content -Path $SettingsPath -Raw | ConvertFrom-Json -AsHashtable
$settings["statusLine"] = @{
    type    = "command"
    command = "bash ~/.claude/statusline-context.sh"
}
$settings | ConvertTo-Json -Depth 20 | Set-Content -Path $SettingsPath -Encoding utf8

Write-Host "Merged statusLine into $SettingsPath"
Write-Host "Restart Claude Code to see it take effect."
