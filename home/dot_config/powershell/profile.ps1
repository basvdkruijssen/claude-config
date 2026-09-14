# ~/.config/powershell/profile.ps1
#
# Migrated from $env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1.
# Dot-source this file from your real $PROFILE, so a OneDrive redirect of
# Documents\PowerShell never gets in the way of your config:
#
#   New-Item -ItemType File -Path $PROFILE -Force
#   Add-Content $PROFILE '. "$HOME\.config\powershell\profile.ps1"'

# Non-interactive sessions (scripts, tooling, CI) need no prompt, modules or
# completers; skip the rest of this profile.
if ([Console]::IsOutputRedirected -or [Console]::IsInputRedirected) { return }

# ── Prompt: Starship (replaces Oh My Posh) ────────────────────────────────────
$env:STARSHIP_CONFIG = Join-Path $HOME '.config\starship.toml'

if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (& starship init powershell)
}
else {
    Write-Host 'Starship not found. Install it with: winget install --id Starship.Starship' -ForegroundColor Yellow
}

# ── Terminal-Icons ────────────────────────────────────────────────────────────
if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Import-Module Terminal-Icons
}

# ── PSReadLine ────────────────────────────────────────────────────────────────
# PredictionSource is HistoryAndPlugin (was History) so that Az.Tools.Predictor
# can actually supply suggestions.
Set-PSReadLineKeyHandler -Key Tab -Function Complete
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -HistoryNoDuplicates
Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# ── Az Predictor ──────────────────────────────────────────────────────────────
# Importing is enough; -AllSession is not needed because this profile loads every session.
if (Get-Module -ListAvailable -Name Az.Tools.Predictor) {
    Import-Module Az.Tools.Predictor
}

# ── Winget autocompleter ──────────────────────────────────────────────────────
# Source: https://github.com/microsoft/winget-cli/blob/master/doc/Completion.md
if (Get-Command winget -ErrorAction Ignore) {
    Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
        $Local:word = $wordToComplete.Replace('"', '""')
        $Local:ast = $commandAst.ToString().Replace('"', '""')
        winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}

# ── Azure CLI autocompleter ───────────────────────────────────────────────────
# Source: https://learn.microsoft.com/cli/azure/install-azure-cli-windows#enable-tab-completion-in-powershell
if (Get-Command az -ErrorAction Ignore) {
    Register-ArgumentCompleter -Native -CommandName az -ScriptBlock {
        param($commandName, $wordToComplete, $cursorPosition)
        $completion_file = New-TemporaryFile
        $env:ARGCOMPLETE_USE_TEMPFILES = 1
        $env:_ARGCOMPLETE_STDOUT_FILENAME = $completion_file
        $env:COMP_LINE = $wordToComplete
        $env:COMP_POINT = $cursorPosition
        $env:_ARGCOMPLETE = 1
        $env:_ARGCOMPLETE_SUPPRESS_SPACE = 0
        $env:_ARGCOMPLETE_IFS = "`n"
        $env:_ARGCOMPLETE_SHELL = 'powershell'
        az 2>&1 | Out-Null
        Get-Content $completion_file | Sort-Object | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
        Remove-Item $completion_file, Env:\_ARGCOMPLETE_STDOUT_FILENAME, Env:\ARGCOMPLETE_USE_TEMPFILES, Env:\COMP_LINE, Env:\COMP_POINT, Env:\_ARGCOMPLETE, Env:\_ARGCOMPLETE_SUPPRESS_SPACE, Env:\_ARGCOMPLETE_IFS, Env:\_ARGCOMPLETE_SHELL
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
    Interactively switch the Azure subscription.
    #>
    $subs = az account list --query '[].{name:name, id:id}' -o json | ConvertFrom-Json
    if (-not $subs) { Write-Warning 'No subscriptions found. Run az login first.'; return }

    $i = 0
    $subs | ForEach-Object { Write-Host ("[{0}] {1}" -f $i, $_.name); $i++ }
    $choice = Read-Host 'Number'

    if ($choice -match '^\d+$' -and [int]$choice -lt $subs.Count) {
        az account set --subscription $subs[[int]$choice].id
        azwho
    }
    else { Write-Warning 'Invalid choice.' }
}

# ── Claude Code ───────────────────────────────────────────────────────────────
Set-Alias cc claude

# ── Machine-specific additions ────────────────────────────────────────────────
# Anything that doesn't belong in the repo (client-specific functions, paths,
# tokens) goes in ~/.config/powershell/profile.local.ps1, which is gitignored.
$localProfile = Join-Path $HOME '.config\powershell\profile.local.ps1'
if (Test-Path $localProfile) { . $localProfile }
