# Build the Claude Desktop skill zips from the Claude Code plugin's skills, so
# plugins/bvdk-pstack-discipline/skills/ stays the single source of truth: the
# four standalone skills are copied as-is, and the principle-* skills are
# bundled into one engineering-principles skill (Desktop skills are uploaded one
# zip at a time; 23 near-empty zips isn't practical). Upload the zips by hand at
# Claude Desktop > Settings > Features > Skills > Upload. Desktop has no
# marketplace or git-sync mechanism, so repeat this after the skills change.
#
# scripts/package-desktop-skills.sh is the macOS/Linux twin and produces the
# same bytes; keep the two in sync.
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$SkillsDir = Join-Path $RepoRoot "plugins\bvdk-pstack-discipline\skills"
$OutDir = Join-Path $RepoRoot "dist\desktop-skills"
$Standalone = @("unslop", "no-comments", "technical-writing", "bro")

if (Test-Path $OutDir) { Remove-Item $OutDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# LF-only UTF-8 without BOM, so the output matches the .sh script byte for byte.
function Write-Lf {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

# Everything below the frontmatter, LF line endings, no leading/trailing blank lines.
function Get-SkillBody {
    param([string]$Path)
    $lines = ([System.IO.File]::ReadAllText($Path) -replace "`r", "") -split "`n"
    $fm = 0
    $body = foreach ($line in $lines) {
        if ($fm -lt 2) {
            if ($line -eq "---") { $fm++ }
            continue
        }
        $line
    }
    ($body -join "`n").Trim("`n")
}

foreach ($name in $Standalone) {
    $dir = New-Item -ItemType Directory -Force -Path (Join-Path $OutDir $name)
    $text = [System.IO.File]::ReadAllText((Join-Path $SkillsDir "$name\SKILL.md")) -replace "`r", ""
    Write-Lf -Path (Join-Path $dir "SKILL.md") -Content $text
}

$principles = Get-ChildItem -Path (Join-Path $SkillsDir "principle-*") -Directory |
    Sort-Object Name |
    ForEach-Object { Join-Path $_.FullName "SKILL.md" }
$count = $principles.Count
$header = @"
---
name: engineering-principles
description: Reference index of $count engineering principles (core design, architecture, verification, delegation, meta) ported from pstack. Ask to apply one by name, e.g. "apply the fix-root-causes principle here".
---

# Engineering principles

$count short rules. Ported from pstack (cursor/plugins), MIT licensed, see NOTICE.md in the source repo. Each is its own skill in the Claude Code plugin; bundled into one document here because Claude Desktop skills are uploaded as individual zips and $count near-empty zips isn't practical. Ask for one by name.
"@ -replace "`r", ""

$sections = foreach ($f in $principles) {
    # Cross-links between principles point at sibling skill folders in the
    # plugin; inside one document they become heading anchors.
    $body = (Get-SkillBody -Path $f) -replace '\]\(\.\./principle-([a-z0-9-]+)/SKILL\.md\)', '](#$1)'
    "`n---`n`n" + $body + "`n"
}
$bundleDir = New-Item -ItemType Directory -Force -Path (Join-Path $OutDir "engineering-principles")
Write-Lf -Path (Join-Path $bundleDir "SKILL.md") -Content ($header + "`n" + ($sections -join ""))

foreach ($dir in Get-ChildItem -Path $OutDir -Directory) {
    $zip = Join-Path $OutDir "$($dir.Name).zip"
    Compress-Archive -Path (Join-Path $dir.FullName "*") -DestinationPath $zip
    Write-Host "Built $zip"
}

Write-Host "Upload each zip in $OutDir at: Claude Desktop > Settings > Features > Skills > Upload"
