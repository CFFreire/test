#!/usr/bin/env bash

set -Eeuo pipefail

echo "=================================================="
echo "     macOS Development Workstation Bootstrap"
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

    if ! grep -q '/opt/homebrew/bin/brew shellenv' \
        "$HOME/.zprofile" 2>/dev/null; then

        echo >> "$HOME/.zprofile"
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' \
            >> "$HOME/.zprofile"
    fi

# Intel
elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

brew update

# ============================================================
# 2. BREWFILE TEMPORAL
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
# CLI / BASE
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
brew "kubectl"
brew "helm"

# ============================================================
# UTILIDADES
# ============================================================

brew "openssl@3"
brew "coreutils"

# ============================================================
# APLICACIONES
# ============================================================

cask "visual-studio-code"

cask "docker-desktop"

cask "chatgpt"

cask "google-chrome"

cask "iterm2"

EOF

brew bundle --file="$BREWFILE"

# ============================================================
# 3. NVM
# ============================================================

echo
echo ">>> Configurando NVM"

mkdir -p "$HOME/.nvm"

NVM_PREFIX="$(brew --prefix nvm)"

if ! grep -q 'NVM_DIR="$HOME/.nvm"' \
    "$HOME/.zshrc" 2>/dev/null; then

cat >> "$HOME/.zshrc" <<EOF

# ============================================================
# NVM
# ============================================================

export NVM_DIR="\$HOME/.nvm"

[ -s "$NVM_PREFIX/nvm.sh" ] && \
    \. "$NVM_PREFIX/nvm.sh"

EOF

fi

export NVM_DIR="$HOME/.nvm"

# shellcheck disable=SC1091
source "$NVM_PREFIX/nvm.sh"

# ============================================================
# 4. NODE LTS + NPM
# ============================================================

echo
echo ">>> Node.js LTS"

nvm install --lts
nvm alias default 'lts/*'
nvm use default

echo
echo "Node:"
node --version

echo
echo "npm:"
npm --version

# ============================================================
# 5. PNPM
# ============================================================

echo
echo ">>> pnpm"

npm install -g pnpm

# ============================================================
# 6. AI DEVELOPMENT TOOLS
# ============================================================

echo
echo ">>> Claude Code"

npm install -g @anthropic-ai/claude-code

echo
echo ">>> OpenAI Codex"

npm install -g @openai/codex

# ============================================================
# 7. DIRECTORIOS DE PROYECTOS
# ============================================================

echo
echo ">>> Creando directorios de proyectos"

mkdir -p \
    "$HOME/Projects/personal" \
    "$HOME/Projects/work" \
    "$HOME/Projects/labs"

# ============================================================
# 8. SSH
# ============================================================

echo
echo ">>> Configurando estructura SSH"

mkdir -p "$HOME/.ssh"

chmod 700 "$HOME/.ssh"

if [[ ! -f "$HOME/.ssh/config" ]]; then
    touch "$HOME/.ssh/config"
fi

chmod 600 "$HOME/.ssh/config"

# IMPORTANTE:
# No generamos ni sobrescribimos claves SSH.
# Esto evita destruir configuraciones existentes.

# ============================================================
# 9. GIT
# ============================================================

echo
echo ">>> Configuración base de Git"

git config --global init.defaultBranch main
git config --global core.autocrlf input
git config --global pull.rebase false
git config --global fetch.prune true
git config --global push.autoSetupRemote true

# ============================================================
# 10. VS CODE
# ============================================================

echo
echo ">>> VS Code extensions"

if [[ -x \
"/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]]; then

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

    echo "WARNING: VS Code CLI no encontrado."

fi

# ============================================================
# 11. ALIASES
# ============================================================

echo
echo ">>> Configurando aliases"

if ! grep -q '# DEV MACHINE ALIASES' \
    "$HOME/.zshrc" 2>/dev/null; then

cat >> "$HOME/.zshrc" <<'EOF'


# ============================================================
# DEV MACHINE ALIASES
# ============================================================

# General

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
# 12. JAVA PATH
# ============================================================

echo
echo ">>> Configurando Java"

JAVA_PREFIX="$(brew --prefix openjdk)"

if ! grep -q "$JAVA_PREFIX/bin" \
    "$HOME/.zshrc" 2>/dev/null; then

cat >> "$HOME/.zshrc" <<EOF


# ============================================================
# JAVA
# ============================================================

export PATH="$JAVA_PREFIX/bin:\$PATH"

EOF

fi

export PATH="$JAVA_PREFIX/bin:$PATH"

# ============================================================
# 13. FZF
# ============================================================

echo
echo ">>> Configurando fzf"

FZF_INSTALL="$(brew --prefix)/opt/fzf/install"

if [[ -f "$FZF_INSTALL" ]]; then

    "$FZF_INSTALL" \
        --key-bindings \
        --completion \
        --no-update-rc || true

fi

# ============================================================
# 14. VERIFICACIÓN
# ============================================================

echo
echo "=================================================="
echo "              VERIFICACIÓN"
echo "=================================================="

verify() {

    local cmd="$1"

    if command -v "$cmd" >/dev/null 2>&1; then

        printf "  %-15s OK\n" "$cmd"

    else

        printf "  %-15s MISSING\n" "$cmd"

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
echo "          VERSIONES PRINCIPALES"
echo "=================================================="

git --version || true

node --version || true
npm --version || true
pnpm --version || true

python3 --version || true

java --version || true
mvn --version || true
gradle --version || true

aws --version || true

kubectl version --client || true

helm version --short || true

claude --version || true

codex --version || true

# ============================================================
# 16. RESULTADO
# ============================================================

echo
echo "=================================================="
echo "       DEVELOPMENT MACHINE READY"
echo "=================================================="

echo
echo "Directorios:"
echo
echo "  ~/Projects/"
echo "      personal/"
echo "      work/"
echo "      labs/"

echo
echo "Herramientas principales:"
echo
echo "  Git / GitHub CLI"
echo "  Node LTS / npm / pnpm"
echo "  Python / pipx"
echo "  Java / Maven / Gradle"
echo "  AWS CLI"
echo "  kubectl / Helm"
echo "  Docker Desktop"
echo "  VS Code"
echo "  Claude Code"
echo "  OpenAI Codex"
echo "  ChatGPT"
echo "  Chrome"
echo "  iTerm2"

echo
echo "Pendiente de autenticación:"
echo
echo "  GitHub:"
echo "      gh auth login"
echo
echo "  AWS:"
echo "      aws configure"
echo "      o configurar AWS SSO"
echo
echo "  Claude:"
echo "      claude"
echo
echo "  Codex:"
echo "      codex"

echo
echo "IMPORTANTE:"
echo
echo "  Abre Docker Desktop una vez para completar"
echo "  su configuración inicial."
echo
echo "Después ejecuta:"
echo
echo "  source ~/.zshrc"

echo
echo "Bootstrap terminado."
echo
