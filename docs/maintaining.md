# Maintaining this repo

## Adding a skill

Add a `SKILL.md` under `plugins/bvdk-pstack-discipline/skills/<name>/`. Bump
`version` in both `.claude-plugin/plugin.json` and the marketplace entry, then
commit and push. Each machine picks it up with `claude plugin update`.

A new `principle-*` skill lands in the Desktop bundle automatically. A new
standalone skill needs adding to the `STANDALONE` list in both
`scripts/package-desktop-skills.*` to get its own Desktop zip.

## Pulling upstream pstack changes

The pstack skills are a manual port. Re-check the source files listed in
`NOTICE.md` periodically and re-copy by hand if they changed meaningfully.

## Editing deployed files

The global `CLAUDE.md`, status line, prompt and shell dotfiles live under
`home/` and deploy through chezmoi. Edit them with `chezmoi edit`, commit and
push, then run `chezmoi update` on other machines. Do not hand-type or
LLM-edit Nerd Font glyphs in `starship.toml`; see `CLAUDE.md` for why.

## Migrating a machine set up from the old `starship` repo

`chezmoi init <repo>` only clones into `~/.local/share/chezmoi` when no git
repo exists there. On such a machine it is still a clone of the old `starship`
repo, so chezmoi keeps that remote. The setup script detects this, skips
`chezmoi apply` and warns. With a clean `git -C ~/.local/share/chezmoi status`,
reset and re-run:

```bash
rm -rf ~/.local/share/chezmoi && ./scripts/setup.sh   # Remove-Item on Windows
```

## Testing `setup.ps1` on a fresh Windows VM

`setup.ps1` needs an interactive logon session (RDP or console). It cannot be
validated headlessly, for example through Azure VM Run Command or a
non-interactive scheduled task. Confirmed on Windows Server 2022 and a
Windows 11 client image.

- Windows Server images ship without winget. Sideloading
  `Microsoft.DesktopAppInstaller` with its dependencies (VCLibs, Windows App
  Runtime; the `DesktopAppInstaller_Dependencies.zip` asset on each
  [winget-cli release](https://github.com/microsoft/winget-cli/releases))
  works, but `Add-AppxPackage` refuses to run as `NT AUTHORITY\SYSTEM`
  (`HRESULT 0x80073CF9`). Run it as a real user, for example through a
  scheduled task created with `schtasks /RU <user> /RP <password>`.
- Windows 11 client images ship winget, but outside an interactive session
  `winget.exe` fails with `STATUS_DLL_NOT_FOUND` (`0xC0000135`). Packaged
  (MSIX) apps need the AppModel activation infrastructure of a logged-on
  desktop.
- The first step (`Checking dependencies`) therefore reports `winget: not
  found` and exits in both headless cases. Git and PowerShell 7 install and
  run fine non-interactively.
- The Nerd Font step drives a `Shell.Application` COM object against the
  Explorer shell namespace and likely fails headlessly for the same reason.

To test end to end, RDP in and run the script from an interactive PowerShell 7
session. Headless automation can provision the VM and install git and pwsh
beforehand.
