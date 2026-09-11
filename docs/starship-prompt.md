<!--
This file (from here to the end) is the original README of the standalone
`basvdkruijssen/starship` repo, kept verbatim (still in Dutch) after that
repo's dotfiles were folded into this one under `home/`. The per-OS install
steps below are now automated by this repo's root `setup.sh`/`setup.ps1`
(they call `chezmoi init --apply` against this repo instead of the old
standalone one) — read this file for the "why" behind the prompt design,
troubleshooting, and day-to-day chezmoi commands, not for setup steps.
-->

# starship

Cross-shell terminal prompt op basis van [Starship](https://starship.rs), toegespitst
op werken met **Azure**, **Terraform** en **Claude Code**. Werkt met dezelfde config in
PowerShell 7, bash en zsh en wordt met [chezmoi](https://www.chezmoi.io) uitgerold op
meerdere machines.

Vervangt de losse gists (`Microsoft.PowerShell_profile.ps1`, `ohmyposh.omp.json`,
`terminal-setup.txt`) door één versiebeheerde bron.

## Wat de prompt toont

Gebaseerd op Starship's ingebouwde [`catppuccin-powerline`
preset](https://starship.rs/presets/#catppuccin-powerline), in de **Mocha**-flavour
(`starship preset catppuccin-powerline`), met de projectspecifieke segmenten
teruggezet. Elk segment heeft een eigen icoon zodat je in één oogopslag ziet welk
stukje van de prompt bij welke bron hoort. Het prompt-teken staat op een eigen
regel onder de rest, zodat getypte input nooit naast een lange statusregel komt.

| Icoon | Segment | Bron | Wanneer zichtbaar |
| --- | --- | --- | --- |
|  | lokale tijd | systeemklok | altijd, eerste segment (lavender-blok) |
|  | `claude-code` | `$CLAUDECODE` | de shell loopt binnen een Claude Code-sessie |
| 󰉋 | pad | working directory | altijd, afgekapt tot de repo-root (peach-blok) |
|  | branch | git | in een git-repo (yellow-blok) |
|  | merge/rebase-status | git | tijdens een merge, rebase, revert, ... (yellow-blok) |
| ⇡⇣!+?... | git-status | git | ingebouwde glyphs per status: ahead/behind/modified/staged/... (yellow-blok) |
|  | .NET-versie | `.csproj` e.d. | in een .NET-project (green-blok) |
|  | Python-versie | `.py`, `venv`, ... | in een Python-project (green-blok) |
|  | `claude` | `CLAUDE.md` | de repo heeft een `CLAUDE.md` (niet op `.claude/`, want anders vuurt dit ook in `~` af) |
| 󰠅 | `plat-prd as user@bedrijf.nl` | `az account show` | Azure CLI is ingelogd; toont subscription + ingelogde gebruiker |
| 󱁢 | `default` | Terraform-workspace | `.tf`-bestanden of `.terraform/` aanwezig |
|  | `took 4s` | vorige commando | commando duurde langer dan 2 seconden |
| ❯ / ❮ | prompt-teken | shell-modus | op eigen regel onder de rest; ❮ in vim-modus |

Kubernetes, AWS, GCP, Node, Rust, Go en package-versies staan uit om ruis te
beperken; `$os`/`$username` uit de preset zijn bewust weggelaten (persoonlijke
devmachine, geen toegevoegde waarde). Andere flavour proberen? Zet `palette` in
`starship.toml` op `catppuccin_latte`, `catppuccin_frappe` of
`catppuccin_macchiato` — alle vier staan al in het bestand.

## Wat de repo beheert

| Bestand in de repo | Doelpad | Platform |
| --- | --- | --- |
| `home/dot_config/starship.toml` | `~/.config/starship.toml` | alle |
| `home/dot_config/powershell/profile.ps1` | `~/.config/powershell/profile.ps1` | Windows |
| `home/dot_config/shell/init.sh` | `~/.config/shell/init.sh` | Linux, WSL, macOS |
| `home/.chezmoiscripts/run_onchange_install-psmodules.ps1.tmpl` | installeert Terminal-Icons, Az, Az.Tools.Predictor | Windows |

Nog toe te voegen (inhoud is machinegebonden, zie
[Bestaande settings toevoegen](#bestaande-settings-toevoegen)): Windows Terminal
`settings.json` en eventueel VS Code `settings.json`.

## Structuur

```
.
├── .chezmoiroot                     # verwijst naar home/ als chezmoi-source
├── .gitignore
├── README.md
├── setup.ps1                        # geautomatiseerde installatie, Windows
├── setup.sh                         # geautomatiseerde installatie, Linux/WSL/macOS
└── home/                            # alles hieronder wordt naar ~ uitgerold
    ├── .chezmoi.toml.tmpl           # machinespecifieke waarden + ps1-interpreter
    ├── .chezmoiignore               # sluit PowerShell uit op Linux en vice versa
    ├── .chezmoiscripts/             # scripts, worden zelf niet uitgerold
    │   └── run_onchange_install-psmodules.ps1.tmpl
    └── dot_config/
        ├── starship.toml
        ├── powershell/profile.ps1
        └── shell/init.sh
```

Chezmoi zet `dot_` om naar een punt bij het uitrollen. Door `.chezmoiroot` blijven
`README.md` en `.gitignore` buiten de uitrol.

---

## Installatie op een nieuwe machine

Elk platform heeft een script dat onderstaande stappen automatiseert, op het
installeren van de Nerd Font in je terminal-emulator na (dat kan niet vanuit een
script). Handmatig stap voor stap kan ook, zie hieronder.

Deze repo is **privé**, dus `curl`/`irm` op de raw-URL werkt niet zonder
authenticatie. Gebruik in plaats daarvan `gh api`, na `gh auth login`.

**Belangrijk:** `gh`-authenticatie is per installatie. WSL heeft een eigen
`gh`-binary en eigen config, los van Windows — een login op Windows telt niet
mee in WSL (en andersom). Log dus in op elke omgeving waar je dit uitvoert:

```bash
gh auth login
```

Kies **HTTPS** en antwoord **Yes** op "Authenticate Git with your GitHub
credentials?" (of run dit achteraf los):

```bash
gh auth setup-git
```

Dit zet `gh` als credential helper voor `github.com`, zodat ook de git-clone
die `chezmoi init` hieronder uitvoert automatisch authenticeert. Zonder deze
stap vraagt git tijdens die clone om een "Username for 'https://github.com'"
en loopt de installatie vast. Controleren:

```bash
gh auth status
git ls-remote https://github.com/basvdkruijssen/starship.git   # geen prompt = goed
```

```powershell
# Windows (PowerShell 7)
gh api repos/basvdkruijssen/starship/contents/setup.ps1 -H "Accept: application/vnd.github.raw" | Out-String | iex
```

`Out-String` is nodig omdat `gh` het script als losse regelobjecten naar de
pipeline stuurt; zonder `Out-String` voert `iex` elke regel los uit en loopt
het meerregelige commentaarblok stuk.

```bash
# Linux, WSL, macOS (bash of zsh)
gh api repos/basvdkruijssen/starship/contents/setup.sh -H "Accept: application/vnd.github.raw" | bash
```

### Windows (PowerShell 7)

**Stap 1 — Nerd Font installeren.** Zonder Nerd Font zie je lege blokjes in plaats
van icoontjes.

```powershell
winget install --id DEVCOM.JetBrainsMonoNerdFont
```

Deze winget-package loopt achter op upstream Nerd Fonts (op het moment van
schrijven v3.3.0) en mist daardoor het `cod-claude`-icoon (U+EC82) dat de Claude
Code-indicatoren in `starship.toml` gebruiken — die tonen dan een fallback-icoon.
`setup.ps1` installeert daarom in plaats daarvan rechtstreeks de nieuwste losse
release van [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts/releases); volg
je liever deze handmatige stappen, download dan `JetBrainsMono.zip` van die
releasepagina en installeer de `.ttf`-bestanden via rechtsklikken → Installeren.

Stel daarna `JetBrainsMono Nerd Font` in als font in:
- Windows Terminal: Settings → Profiles → Defaults → Appearance → Font face
- VS Code: instelling `terminal.integrated.fontFamily`

**Stap 2 — Tooling installeren.**

```powershell
winget install --id Microsoft.PowerShell --accept-package-agreements --accept-source-agreements
winget install --id Starship.Starship
winget install --id twpayne.chezmoi
```

Sluit je terminal en open een nieuwe, zodat `PATH` is bijgewerkt.

**Stap 3 — Dotfiles uitrollen.** Chezmoi installeert hierbij ook de PowerShell-modules.

```powershell
chezmoi init --apply github.com/basvdkruijssen/starship
```

Je wordt eenmalig gevraagd om het machinetype (`work` of `personal`).

**Stap 4 — Profiel koppelen.**

```powershell
if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force }
Add-Content $PROFILE '. "$HOME\.config\powershell\profile.ps1"'
```

**Stap 5 — Herstarten en controleren.**

```powershell
. $PROFILE
starship --version
```

### Linux, WSL en macOS (bash of zsh)

**Stap 1 — Nerd Font installeren.**

```bash
brew install --cask font-jetbrains-mono-nerd-font   # macOS
```

Op WSL installeer je het font in Windows; de terminal-emulator bepaalt het font,
niet de Linux-kant.

**Stap 2 — Tooling installeren.**

```bash
curl -sS https://starship.rs/install.sh | sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"
```

**Stap 3 — Dotfiles uitrollen.**

```bash
chezmoi init --apply github.com/basvdkruijssen/starship
```

**Stap 4 — Shell koppelen.**

```bash
# bash
echo '[ -f "$HOME/.config/shell/init.sh" ] && . "$HOME/.config/shell/init.sh"' >> ~/.bashrc

# zsh
echo '[ -f "$HOME/.config/shell/init.sh" ] && . "$HOME/.config/shell/init.sh"' >> ~/.zshrc
```

**Stap 5 — Herstarten en controleren.**

```bash
exec "$SHELL" -l
starship --version
```

---

## Migratie vanaf de bestaande setup

Op machines waar het oude profiel met Oh My Posh nog staat:

```powershell
# 1. Oude profiel bewaren
$old = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
Copy-Item $old "$old.bak" -Force

# 2. Vervangen door een verwijzing naar de repo-versie
Set-Content $old '. "$HOME\.config\powershell\profile.ps1"'

# 3. Controleren of er nog iets in $old.bak staat dat niet in de repo zit;
#    machinespecifieke dingen gaan naar ~/.config/powershell/profile.local.ps1
```

Wat is overgenomen uit het oude profiel: Terminal-Icons, de PSReadLine-instellingen,
de winget-completer en Az.Tools.Predictor. Twee wijzigingen:

- Oh My Posh is vervangen door Starship. `ohmyposh.omp.json` is niet meer nodig; laat
  de gist staan als archief of verwijder hem.
- `PredictionSource` staat op `HistoryAndPlugin` in plaats van `History`, anders levert
  Az.Tools.Predictor geen suggesties.

### Bestaande settings toevoegen

Voeg deze op je hoofdmachine één keer toe; daarna rollen ze mee naar de rest.

```powershell
# Windows Terminal
chezmoi add "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

# VS Code (optioneel)
chezmoi add "$env:APPDATA\Code\User\settings.json"

chezmoi cd
git add -A ; git commit -m "Windows Terminal en VS Code settings toegevoegd" ; git push
exit
```

Gebruik je Windows Terminal niet uit de Store maar de unpackaged versie, dan is het pad
`$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json`.

Controleer `settings.json` na toevoegen op zaken die niet in een repo horen, zoals
lokale gebruikersnamen in `startingDirectory` of `commandline`. Maak er zo nodig een
`.tmpl` van en vervang die door `{{ .chezmoi.homeDir }}`.

---

## Wijzigingen doorvoeren

Bewerk altijd via chezmoi, niet direct in `~`, anders raken repo en machine uit elkaar.

```bash
chezmoi edit ~/.config/starship.toml   # bewerk de bron
chezmoi diff                           # zie wat er zou veranderen
chezmoi apply                          # pas toe op deze machine
chezmoi cd                             # ga naar de repo
git commit -am "Prompt: segment X aangepast" && git push
exit
```

Op de andere machines:

```bash
chezmoi update                         # pull + apply in één stap
```

---

## Aanpassen aan je eigen omgeving

**Azure subscription-aliases.** De sleutels in `[azure.subscription_aliases]` in
`home/dot_config/starship.toml` moeten exact overeenkomen met de output van
`az account list -o table`. De meegeleverde waarden zijn voorbeelden; kloppen ze niet,
dan toont de prompt de volledige lange subscriptionnaam.

**Machinespecifieke aanvullingen.** Zet klantspecifieke functies, paden of tokens in
`~/.config/powershell/profile.local.ps1` of `~/.config/shell/init.local.sh`. Beide
worden automatisch geladen als ze bestaan en staan in `.gitignore`.

**Per-machine verschillen in de config zelf.** Hernoem `starship.toml` naar
`starship.toml.tmpl` en gebruik de variabele uit `.chezmoi.toml.tmpl`:

```toml
{{ if eq .machineType "work" }}
[azure]
disabled = false
{{ end }}
```

**Az-module kleiner maken.** De volledige `Az`-module is ongeveer 1 GB. Vervang hem in
`run_onchange_install-psmodules.ps1.tmpl` door alleen wat je gebruikt, bijvoorbeeld
`Az.Accounts` en `Az.Resources`.

**Performance.** Het `[custom.claude]`-segment start één subproces per prompt. Merk je
vertraging, verwijder dat blok; de `[env_var.CLAUDECODE]`-indicator kost niets.
Terraform-versie wordt bewust niet getoond, omdat `terraform version` te traag is om per
prompt uit te voeren.

---

## Troubleshooting

| Symptoom | Oorzaak en oplossing |
| --- | --- |
| Lege blokjes of vraagtekens | Nerd Font niet ingesteld in de terminal-emulator |
| Prompt onveranderd na installatie | `$PROFILE` of `~/.bashrc` niet gekoppeld; check stap 4 |
| Twee prompts of dubbele init | Oud Oh My Posh-profiel staat er nog; zie Migratie |
| Geen Azure-segment | Niet ingelogd: `az login` |
| Volledige lange subscriptionnaam | Alias-sleutel matcht niet exact met `az account list -o table` |
| Modules niet geïnstalleerd | Script alleen op Windows; forceer met `chezmoi apply --force` |
| `chezmoi apply` overschrijft niets | Bestand handmatig gewijzigd; los op met `chezmoi merge <pad>` |
| `Username for 'https://github.com'` tijdens `chezmoi init` | Git-credential-helper niet gekoppeld aan `gh`; run `gh auth setup-git` (per omgeving, WSL telt los van Windows) |
| `fork/exec ...install-psmodules.ps1: exec format error` op Linux/WSL/macOS | Verouderde source state van vóór de fix (`.chezmoiignore` sluit scripts niet uit, dus het `.ps1`-script moest een self-guarding `.tmpl` worden). Los op met `chezmoi update` |
