# ~/.config/shell/init.sh
#
# Source dit bestand vanuit ~/.bashrc of ~/.zshrc:
#   [ -f "$HOME/.config/shell/init.sh" ] && . "$HOME/.config/shell/init.sh"

export STARSHIP_CONFIG="$HOME/.config/starship.toml"

if command -v starship >/dev/null 2>&1; then
  if [ -n "$ZSH_VERSION" ]; then
    eval "$(starship init zsh)"
  elif [ -n "$BASH_VERSION" ]; then
    eval "$(starship init bash)"
  fi
else
  echo "Starship niet gevonden: curl -sS https://starship.rs/install.sh | sh" >&2
fi

# ── Terraform ─────────────────────────────────────────────────────────────────
alias tf='terraform'
alias tfi='terraform init'
alias tfp='terraform plan -out=tfplan'
alias tfa='terraform apply tfplan'
alias tfv='terraform validate'
alias tff='terraform fmt -recursive'

# ── Azure CLI ─────────────────────────────────────────────────────────────────
alias azwho='az account show --query "{subscription:name, tenant:tenantId, user:user.name}" -o yaml'

azsw() {
  # Interactief wisselen van Azure subscription (met fzf indien aanwezig).
  if command -v fzf >/dev/null 2>&1; then
    local sub
    sub=$(az account list --query '[].name' -o tsv | fzf --prompt='Subscription> ') || return
    [ -n "$sub" ] && az account set --subscription "$sub" && azwho
  else
    az account list --query '[].{Name:name, Id:id}' -o table
    printf 'Subscription (naam of id): '
    read -r sub
    [ -n "$sub" ] && az account set --subscription "$sub" && azwho
  fi
}

# ── Claude Code ───────────────────────────────────────────────────────────────
alias cc='claude'

# ── Machine-specifieke aanvullingen ───────────────────────────────────────────
# Niet in de repo: ~/.config/shell/init.local.sh (staat in .gitignore).
[ -f "$HOME/.config/shell/init.local.sh" ] && . "$HOME/.config/shell/init.local.sh"
