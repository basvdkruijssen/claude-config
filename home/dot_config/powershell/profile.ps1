# ~/.config/powershell/profile.ps1
#
# Gemigreerd vanaf $env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1.
# Dot-source dit bestand vanuit je echte $PROFILE, zodat de OneDrive-redirect van
# Documents\PowerShell je config niet in de weg zit:
#
#   New-Item -ItemType File -Path $PROFILE -Force
#   Add-Content $PROFILE '. "$HOME\.config\powershell\profile.ps1"'

# ── Prompt: Starship (vervangt Oh My Posh) ────────────────────────────────────
$env:STARSHIP_CONFIG = Join-Path $HOME '.config\starship.toml'

if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (& starship init powershell)
}
else {
    Write-Host 'Starship niet gevonden. Installeer met: winget install --id Starship.Starship' -ForegroundColor Yellow
}

# ── Terminal-Icons ────────────────────────────────────────────────────────────
if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Import-Module Terminal-Icons
}

# ── PSReadLine ────────────────────────────────────────────────────────────────
# PredictionSource staat op HistoryAndPlugin (was History) zodat Az.Tools.Predictor
# daadwerkelijk suggesties kan aanleveren.
Set-PSReadLineKeyHandler -Key Tab -Function Complete
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -HistoryNoDuplicates
Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# ── Az Predictor ──────────────────────────────────────────────────────────────
# Importeren is voldoende; -AllSession is niet nodig omdat dit profiel elke sessie laadt.
if (Get-Module -ListAvailable -Name Az.Tools.Predictor) {
    Import-Module Az.Tools.Predictor
}

# ── Winget autocompleter ──────────────────────────────────────────────────────
# Bron: https://github.com/microsoft/winget-cli/blob/master/doc/Completion.md
Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
    $Local:word = $wordToComplete.Replace('"', '""')
    $Local:ast = $commandAst.ToString().Replace('"', '""')
    winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

# ── Terraform ─────────────────────────────────────────────────────────────────
Set-Alias tf terraform

function tfi { terraform init @args }
function tfp { terraform plan -out=tfplan @args }
function tfa { terraform apply tfplan @args }
function tfv { terraform validate @args }
function tff { terraform fmt -recursive @args }

# ── Azure CLI ─────────────────────────────────────────────────────────────────
function azwho {
    az account show --query '{subscription:name, tenant:tenantId, user:user.name}' -o yaml
}

function azsw {
    <#
    .SYNOPSIS
    Interactief wisselen van Azure subscription.
    #>
    $subs = az account list --query '[].{name:name, id:id}' -o json | ConvertFrom-Json
    if (-not $subs) { Write-Warning 'Geen subscriptions gevonden. Eerst: az login'; return }

    $i = 0
    $subs | ForEach-Object { Write-Host ("[{0}] {1}" -f $i, $_.name); $i++ }
    $choice = Read-Host 'Nummer'

    if ($choice -match '^\d+$' -and [int]$choice -lt $subs.Count) {
        az account set --subscription $subs[[int]$choice].id
        azwho
    }
    else { Write-Warning 'Ongeldige keuze.' }
}

# ── Claude Code ───────────────────────────────────────────────────────────────
Set-Alias cc claude

# ── Machine-specifieke aanvullingen ───────────────────────────────────────────
# Alles wat niet in de repo hoort (klantspecifieke functies, paden, tokens) zet je in
# ~/.config/powershell/profile.local.ps1. Dat bestand staat in .gitignore.
$localProfile = Join-Path $HOME '.config\powershell\profile.local.ps1'
if (Test-Path $localProfile) { . $localProfile }
