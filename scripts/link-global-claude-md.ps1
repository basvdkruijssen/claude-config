# Symlink this repo's claude-code\CLAUDE.md to ~/.claude/CLAUDE.md so edits
# here apply on every machine after a git pull. Backs up an existing file once.
# Creating a symlink on Windows normally needs an elevated shell or Developer
# Mode enabled (Settings > Privacy & security > For developers).
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Src = Join-Path $RepoRoot "claude-code\CLAUDE.md"
$DestDir = Join-Path $HOME ".claude"
$Dest = Join-Path $DestDir "CLAUDE.md"

New-Item -ItemType Directory -Force -Path $DestDir | Out-Null

if ((Test-Path $Dest) -and -not (Get-Item $Dest).LinkType) {
    $ts = Get-Date -Format "yyyyMMddHHmmss"
    Write-Host "Backing up existing $Dest to $Dest.bak.$ts"
    Move-Item $Dest "$Dest.bak.$ts"
}
elseif (Test-Path $Dest) {
    Remove-Item $Dest -Force
}

New-Item -ItemType SymbolicLink -Path $Dest -Target $Src | Out-Null
Write-Host "Linked $Dest -> $Src"
