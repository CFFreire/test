#!/usr/bin/env bash

set -Eeuo pipefail

echo "=================================================="
echo "  macOS Development Workstation Bootstrap"
echo "=================================================="

# ============================================================
# 0. VALIDACIONES
# ============================================================

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "ERROR: Este script es solamente para macOS."
    exit 1
fi

ARCH="$(uname -m)"

echo "Arquitectura: $ARCH"

# ============================================================
# 1. HOMEBREW
# ============================================================

echo
echo ">>> Homebrew"

if ! command -v brew >/dev/null 2>&1; then

    echo "Instalando Homebrew..."

    /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

fi

# Apple Silicon
if [[ -x /opt/homebrew/bin/brew ]]; then

    eval "$(/opt/homebrew/bin/brew shellenv)"

    # Agregar permanentemente al PATH
    if ! grep -q '/opt/homebrew/bin/brew shellenv' "$HOME/.zprofile" 2>/dev/null; then

        echo >> "$HOME/.zprofile"
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"

    fi

# Intel
elif [[ -x /usr/local/bin/brew ]]; then

    eval "$(/usr/local/bin/brew shellenv)"

fi

brew update

# ============================================================
# 2. HASHICORP TAP
# ============================================================

echo
echo ">>> HashiCorp"

brew tap hashicorp/tap

# ============================================================
# 3. BREWFILE TEMPORAL
# ============================================================

echo
echo ">>> Instalando herramientas"

BREWFILE="$(mktemp)"

cleanup() {
    rm -f "$BREWFILE"
}

trap cleanup EXIT

cat > "$BREWFILE" <<'EOF'

# ============================================================
# CLI BASE
# ============================================================

brew "git"
brew "gh"

brew "curl"
brew "wget"

brew "jq"
brew "tree"

brew "ripgrep"
brew "fzf"

brew "tmux"
brew "watch"

brew "shellcheck"

# ============================================================
# NODE
# ============================================================

brew "nvm"

# ============================================================
# PYTHON
# ============================================================

brew "python"
brew "pipx"

# ============================================================
# JAVA
# ============================================================

brew "openjdk"
brew "maven"
brew "gradle"

# ============================================================
# CLOUD / DEVOPS
# ============================================================

brew "awscli"

brew "hashicorp/tap/terraform"

brew "kubectl"
brew "helm"

# ============================================================
# UTILIDADES
# ============================================================

brew "openssl@3"
brew "coreutils"

# ============================================================
# GUI
# ============================================================

cask "visual-studio-code"

cask "docker-desktop"

cask "chatgpt"

cask "google-chrome"

cask "iterm2"

EOF

brew bundle --file="$BREWFILE"

# ============================================================
# 4. NVM
# ============================================================

echo
echo ">>> Configurando NVM"

mkdir -p "$HOME/.nvm"

NVM_PREFIX="$(brew --prefix nvm)"

if ! grep -q 'NVM_DIR="$HOME/.nvm"' "$HOME/.zshrc" 2>/dev/null; then

cat >> "$HOME/.zshrc" <<EOF

# ============================================================
# NVM
# ============================================================

export NVM_DIR="\$HOME/.nvm"

[ -s "$NVM_PREFIX/nvm.sh" ] && \
    \. "$NVM_PREFIX/nvm.sh"

[ -s "$NVM_PREFIX/etc/bash_completion.d/nvm" ] && \
    \. "$NVM_PREFIX/etc/bash_completion.d/nvm"

EOF

fi

export NVM_DIR="$HOME/.nvm"

# shellcheck disable=SC1091
source "$NVM_PREFIX/nvm.sh"

# ============================================================
# 5. NODE LTS
# ============================================================

echo
echo ">>> Node.js LTS"

nvm install --lts

nvm alias default 'lts/*'

nvm use default

echo
echo "Node:"
node --version

echo "npm:"
npm --version

# ============================================================
# 6. PNPM
# ============================================================

echo
echo ">>> pnpm"

npm install -g pnpm

# ============================================================
# 7. AI DEVELOPMENT TOOLS
# ============================================================

echo
echo ">>> Claude Code"

npm install -g @anthropic-ai/claude-code

echo
echo ">>> OpenAI Codex"

npm install -g @openai/codex

# ============================================================
# 8. PROJECT DIRECTORIES
# ============================================================

echo
echo ">>> Creando directorios"

mkdir -p "$HOME/Projects"

mkdir -p "$HOME/Projects/personal"

mkdir -p "$HOME/Projects/work"

mkdir -p "$HOME/Projects/labs"

# ============================================================
# 9. SSH
# ============================================================

echo
echo ">>> SSH"

mkdir -p "$HOME/.ssh"

chmod 700 "$HOME/.ssh"

if [[ ! -f "$HOME/.ssh/config" ]]; then

    touch "$HOME/.ssh/config"

fi

chmod 600 "$HOME/.ssh/config"

# IMPORTANTE:
# No generamos ni sobrescribimos claves automáticamente.
# Las cuentas GitHub se pueden configurar posteriormente.

# ============================================================
# 10. GIT
# ============================================================

echo
echo ">>> Git"

git config --global init.defaultBranch main

git config --global core.autocrlf input

git config --global pull.rebase false

git config --global fetch.prune true

git config --global push.autoSetupRemote true

# ============================================================
# 11. VS CODE
# ============================================================

echo
echo ">>> VS Code extensions"

# Asegurar disponibilidad del comando "code"
if [[ -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]]; then

    CODE_BIN="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"

else

    CODE_BIN="$(command -v code || true)"

fi

if [[ -n "$CODE_BIN" ]]; then

    EXTENSIONS=(

        # Git
        "eamodio.gitlens"

        # JavaScript / TypeScript
        "dbaeumer.vscode-eslint"
        "esbenp.prettier-vscode"

        # Python
        "ms-python.python"

        # Docker
        "ms-azuretools.vscode-docker"

        # Terraform
        "hashicorp.terraform"

        # YAML
        "redhat.vscode-yaml"

        # SSH
        "ms-vscode-remote.remote-ssh"

        # Dev Containers
        "ms-vscode-remote.remote-containers"

    )

    for extension in "${EXTENSIONS[@]}"; do

        echo "Installing VS Code extension: $extension"

        "$CODE_BIN" \
            --install-extension "$extension" \
            --force || true

    done

else

    echo "WARNING: comando VS Code no encontrado."

fi

# ============================================================
# 12. SHELL ALIASES
# ============================================================

echo
echo ">>> Shell aliases"

if ! grep -q '# DEV MACHINE ALIASES' "$HOME/.zshrc" 2>/dev/null; then

cat >> "$HOME/.zshrc" <<'EOF'


# ============================================================
# DEV MACHINE ALIASES
# ============================================================

alias ll='ls -lah'

# Git

alias gs='git status'

alias ga='git add'

alias gc='git commit'

alias gp='git pull'

alias gps='git push'

alias gl='git log --oneline --graph --decorate'

# Docker

alias d='docker'

alias dc='docker compose'

# Kubernetes

alias k='kubectl'

# Projects

alias projects='cd ~/Projects'

alias personal='cd ~/Projects/personal'

alias work='cd ~/Projects/work'

alias labs='cd ~/Projects/labs'

EOF

fi

# ============================================================
# 13. FZF
# ============================================================

echo
echo ">>> fzf"

if [[ -f "$(brew --prefix)/opt/fzf/install" ]]; then

    "$(brew --prefix)/opt/fzf/install" \
        --key-bindings \
        --completion \
        --no-update-rc || true

fi

# ============================================================
# 14. VERIFICACIÓN
# ============================================================

echo
echo "=================================================="
echo " Verificando instalación"
echo "=================================================="

verify() {

    local command="$1"

    if command -v "$command" >/dev/null 2>&1; then

        printf "  %-15s OK\n" "$command"

    else

        printf "  %-15s MISSING\n" "$command"

    fi

}

verify brew

verify git

verify gh

verify node

verify npm

verify pnpm

verify python3

verify pipx

verify java

verify mvn

verify gradle

verify aws

verify terraform

verify kubectl

verify helm

verify docker

verify claude

verify codex

# ============================================================
# 15. VERSIONES
# ============================================================

echo
echo "=================================================="
echo " Versiones principales"
echo "=================================================="

git --version || true

node --version || true

npm --version || true

pnpm --version || true

python3 --version || true

java --version || true

aws --version || true

terraform version || true

kubectl version --client || true

helm version --short || true

claude --version || true

codex --version || true

# ============================================================
# FINAL
# ============================================================

echo
echo "=================================================="
echo "        DEVELOPMENT MACHINE READY"
echo "=================================================="
echo

echo "Directorios:"
echo
echo "  ~/Projects/personal"
echo "  ~/Projects/work"
echo "  ~/Projects/labs"
echo

echo "Pendiente de configuración personal:"
echo
echo "  1. GitHub / SSH multi-cuenta"
echo "  2. gh auth login"
echo "  3. aws configure / AWS SSO"
echo "  4. Claude authentication"
echo "  5. Codex authentication"
echo

echo "IMPORTANTE:"
echo
echo "Abre Docker Desktop una vez para completar su configuración."
echo
echo "Después ejecuta:"
echo
echo "  source ~/.zshrc"
echo

echo "Bootstrap terminado."
