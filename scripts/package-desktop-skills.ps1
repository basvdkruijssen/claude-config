# Zip each desktop-skills/<name>/ folder so it can be uploaded to Claude Desktop
# (Settings > Features > Skills > Upload). Desktop has no marketplace mechanism,
# so this is a manual step you repeat after this repo changes.
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$OutDir = Join-Path $RepoRoot "dist\desktop-skills"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Get-ChildItem -Path (Join-Path $RepoRoot "desktop-skills") -Directory | ForEach-Object {
    $name = $_.Name
    $out = Join-Path $OutDir "$name.zip"
    if (Test-Path $out) { Remove-Item $out -Force }
    Compress-Archive -Path (Join-Path $_.FullName "*") -DestinationPath $out
    Write-Host "Built $out"
}

Write-Host "Upload each zip in $OutDir at: Claude Desktop > Settings > Features > Skills > Upload"
