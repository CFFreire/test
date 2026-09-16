#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# DEV MACHINE SETUP
#
# Soporta:
#   - Ubuntu (ARM64 / x86_64)
#   - macOS (Apple Silicon / Intel)
#
# Instala:
#   - Git + múltiples identidades GitHub
#   - SSH independiente por cuenta
#   - GitHub CLI
#   - VS Code + extensiones
#   - Node.js LTS + npm + pnpm
#   - Python + pipx
#   - Java + Maven + Gradle
#   - Docker Engine (Ubuntu)
#   - Docker Desktop (macOS)
#   - AWS CLI
#   - Terraform
#   - kubectl
#   - Claude Code
#   - OpenAI Codex CLI
#   - herramientas CLI
#
# Puede ejecutarse nuevamente sin destruir claves SSH.
# ============================================================

PROJECTS_DIR="$HOME/Projects"
SSH_DIR="$HOME/.ssh"

# ------------------------------------------------------------
# UI
# ------------------------------------------------------------

section() {
    echo
    echo "============================================================"
    echo " $1"
    echo "============================================================"
}

ok() {
    echo "✓ $1"
}

warn() {
    echo "⚠ $1"
}

exists() {
    command -v "$1" >/dev/null 2>&1
}

# ------------------------------------------------------------
# Detectar sistema
# ------------------------------------------------------------

detect_system() {

    section "Detectando sistema"

    ARCH="$(uname -m)"

    case "$(uname -s)" in

        Darwin)
            OS="macos"
            ;;

        Linux)

            if [[ ! -f /etc/os-release ]]; then
                echo "No puedo identificar esta distribución Linux."
                exit 1
            fi

            . /etc/os-release

            if [[ "$ID" != "ubuntu" ]]; then
                echo "Actualmente este instalador soporta Ubuntu."
                exit 1
            fi

            OS="ubuntu"
            ;;

        *)
            echo "Sistema operativo no soportado."
            exit 1
            ;;
    esac

    ok "Sistema: $OS"
    ok "Arquitectura: $ARCH"
}

# ------------------------------------------------------------
# Homebrew
# ------------------------------------------------------------

install_homebrew() {

    [[ "$OS" == "macos" ]] || return

    section "Homebrew"

    if exists brew; then
        ok "Homebrew ya está instalado"
        return
    fi

    /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [[ -x /opt/homebrew/bin/brew ]]; then

        eval "$(/opt/homebrew/bin/brew shellenv)"

        grep -q "brew shellenv" "$HOME/.zprofile" 2>/dev/null ||
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' \
            >> "$HOME/.zprofile"
    fi

    ok "Homebrew instalado"
}

# ------------------------------------------------------------
# Ubuntu base
# ------------------------------------------------------------

install_ubuntu_base() {

    [[ "$OS" == "ubuntu" ]] || return

    section "Herramientas base Ubuntu"

    sudo apt-get update

    sudo apt-get install -y \
        build-essential \
        ca-certificates \
        curl \
        wget \
        git \
        unzip \
        zip \
        jq \
        tree \
        htop \
        ripgrep \
        fd-find \
        fzf \
        tmux \
        openssh-client \
        gnupg \
        software-properties-common \
        apt-transport-https \
        python3 \
        python3-pip \
        python3-venv \
        pipx

    ok "Herramientas base instaladas"
}

# ------------------------------------------------------------
# macOS base
# ------------------------------------------------------------

install_macos_base() {

    [[ "$OS" == "macos" ]] || return

    section "Herramientas base macOS"

    brew install \
        git \
        gh \
        wget \
        jq \
        tree \
        htop \
        ripgrep \
        fd \
        fzf \
        tmux \
        python \
        pipx

    ok "Herramientas base instaladas"
}

# ------------------------------------------------------------
# GitHub CLI
# ------------------------------------------------------------

install_github_cli() {

    section "GitHub CLI"

    if exists gh; then
        ok "GitHub CLI ya está instalado"
        return
    fi

    if [[ "$OS" == "macos" ]]; then

        brew install gh

    else

        sudo mkdir -p -m 755 /etc/apt/keyrings

        curl -fsSL \
            https://cli.github.com/packages/githubcli-archive-keyring.gpg |
            sudo tee \
            /etc/apt/keyrings/githubcli-archive-keyring.gpg \
            >/dev/null

        sudo chmod go+r \
            /etc/apt/keyrings/githubcli-archive-keyring.gpg

        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
            sudo tee /etc/apt/sources.list.d/github-cli.list \
            >/dev/null

        sudo apt-get update
        sudo apt-get install -y gh
    fi

    ok "GitHub CLI instalado"
}

# ============================================================
# GIT / GITHUB MULTI ACCOUNT
# ============================================================

configure_git_accounts() {

    section "Git / GitHub - múltiples cuentas"

    mkdir -p "$PROJECTS_DIR"
    mkdir -p "$SSH_DIR"

    chmod 700 "$SSH_DIR"

    echo
    echo "Puedes configurar varias cuentas Git/GitHub."
    echo
    echo "Ejemplos de alias:"
    echo "  personal"
    echo "  work"
    echo "  kushki"
    echo "  consulting"
    echo

    read -r -p "¿Cuántas cuentas deseas configurar? [1]: " ACCOUNT_COUNT

    ACCOUNT_COUNT="${ACCOUNT_COUNT:-1}"

    # Configuración Git global básica

    git config --global init.defaultBranch main
    git config --global pull.rebase false
    git config --global core.autocrlf input

    for ((i=1; i<=ACCOUNT_COUNT; i++)); do

        echo
        echo "------------------------------------------------------------"
        echo " Cuenta $i"
        echo "------------------------------------------------------------"

        read -r -p "Alias (ej: personal): " ALIAS
        read -r -p "Nombre Git: " GIT_NAME
        read -r -p "Email Git: " GIT_EMAIL

        # Normalizar alias

        ALIAS="$(echo "$ALIAS" |
            tr '[:upper:]' '[:lower:]' |
            tr -cd 'a-z0-9_-')"

        if [[ -z "$ALIAS" ]]; then
            echo "Alias inválido."
            exit 1
        fi

        ACCOUNT_DIR="$PROJECTS_DIR/$ALIAS"

        GIT_CONFIG="$HOME/.gitconfig-$ALIAS"

        SSH_KEY="$SSH_DIR/id_ed25519_$ALIAS"

        SSH_HOST="github-$ALIAS"

        mkdir -p "$ACCOUNT_DIR"

        # ----------------------------------------------------
        # Git identity
        # ----------------------------------------------------

        cat > "$GIT_CONFIG" <<EOF
[user]
    name = $GIT_NAME
    email = $GIT_EMAIL
EOF

        INCLUDE_PATTERN="gitdir:$ACCOUNT_DIR/"

        # Evitar duplicados

        if ! git config --global \
            --get-all "includeIf.$INCLUDE_PATTERN.path" \
            2>/dev/null |
            grep -Fxq "$GIT_CONFIG"; then

            git config --global \
                "includeIf.$INCLUDE_PATTERN.path" \
                "$GIT_CONFIG"
        fi

        ok "Identidad Git: $ALIAS"

        # ----------------------------------------------------
        # SSH key
        # ----------------------------------------------------

        if [[ ! -f "$SSH_KEY" ]]; then

            ssh-keygen \
                -t ed25519 \
                -C "$GIT_EMAIL" \
                -f "$SSH_KEY" \
                -N ""

            ok "Clave SSH creada"

        else

            ok "Clave SSH existente conservada"
        fi

        chmod 600 "$SSH_KEY"
        chmod 644 "$SSH_KEY.pub"

        # ----------------------------------------------------
        # SSH config
        # ----------------------------------------------------

        touch "$SSH_DIR/config"
        chmod 600 "$SSH_DIR/config"

        START_MARKER="# DEV-SETUP-$ALIAS-START"
        END_MARKER="# DEV-SETUP-$ALIAS-END"

        # Eliminar bloque anterior para poder actualizarlo

        if grep -q "$START_MARKER" "$SSH_DIR/config"; then

            sed -i.bak \
                "/$START_MARKER/,/$END_MARKER/d" \
                "$SSH_DIR/config"

            rm -f "$SSH_DIR/config.bak"
        fi

        cat >> "$SSH_DIR/config" <<EOF

$START_MARKER
Host $SSH_HOST
    HostName github.com
    User git
    IdentityFile $SSH_KEY
    IdentitiesOnly yes
$END_MARKER
EOF

        # ----------------------------------------------------
        # Git URL rewrite SOLO para esa carpeta
        # ----------------------------------------------------

        git config -f "$GIT_CONFIG" \
            "url.git@$SSH_HOST:.insteadOf" \
            "git@github.com:"

        # ----------------------------------------------------
        # Mostrar información
        # ----------------------------------------------------

        echo
        echo "Cuenta '$ALIAS' configurada."
        echo
        echo "Proyectos:"
        echo "  $ACCOUNT_DIR"
        echo
        echo "SSH host:"
        echo "  $SSH_HOST"
        echo
        echo "Clave pública:"
        echo

        cat "$SSH_KEY.pub"

        echo
    done
}

# ============================================================
# NODE / NPM / PNPM
# ============================================================

install_node() {

    section "Node.js + npm + pnpm"

    export NVM_DIR="$HOME/.nvm"

    if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then

        curl -o- \
            https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh |
            bash
    fi

    # shellcheck disable=SC1091

    source "$NVM_DIR/nvm.sh"

    nvm install --lts
    nvm alias default 'lts/*'
    nvm use default

    npm install -g pnpm

    ok "Node $(node --version)"
    ok "npm $(npm --version)"
    ok "pnpm $(pnpm --version)"
}

# ============================================================
# JAVA
# ============================================================

install_java() {

    section "Java"

    if [[ "$OS" == "ubuntu" ]]; then

        sudo apt-get install -y \
            default-jdk \
            maven \
            gradle

    else

        brew install \
            openjdk \
            maven \
            gradle
    fi

    ok "Java instalado"
}

# ============================================================
# VS CODE
# ============================================================

install_vscode() {

    section "Visual Studio Code"

    if exists code; then
        ok "VS Code ya está instalado"
        return
    fi

    if [[ "$OS" == "macos" ]]; then

        brew install --cask visual-studio-code

    else

        wget -qO- \
            https://packages.microsoft.com/keys/microsoft.asc |
            gpg --dearmor > /tmp/packages.microsoft.gpg

        sudo install \
            -D \
            -o root \
            -g root \
            -m 644 \
            /tmp/packages.microsoft.gpg \
            /usr/share/keyrings/packages.microsoft.gpg

        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" |
            sudo tee \
            /etc/apt/sources.list.d/vscode.list \
            >/dev/null

        sudo apt-get update
        sudo apt-get install -y code
    fi

    ok "VS Code instalado"
}

install_vscode_extensions() {

    section "Extensiones VS Code"

    local extensions=(

        # JavaScript / TypeScript
        dbaeumer.vscode-eslint
        esbenp.prettier-vscode

        # Python
        ms-python.python

        # Docker
        ms-azuretools.vscode-docker

        # Git
        eamodio.gitlens

        # YAML
        redhat.vscode-yaml

        # Terraform
        hashicorp.terraform

        # Remote / Containers
        ms-vscode-remote.remote-containers
        ms-vscode-remote.remote-ssh
    )

    for extension in "${extensions[@]}"; do

        echo "→ $extension"

        code \
            --install-extension "$extension" \
            --force \
            >/dev/null 2>&1 || true
    done

    ok "Extensiones instaladas"
}

# ============================================================
# DOCKER
# ============================================================

install_docker() {

    section "Docker"

    # --------------------------------------------------------
    # macOS -> Docker Desktop
    # --------------------------------------------------------

    if [[ "$OS" == "macos" ]]; then

        if [[ -d "/Applications/Docker.app" ]]; then

            ok "Docker Desktop ya está instalado"

        else

            brew install --cask docker

            ok "Docker Desktop instalado"
        fi

        return
    fi

    # --------------------------------------------------------
    # Ubuntu -> Docker Engine
    #
    # Dentro de VirtualBuddy evitamos Docker Desktop porque
    # implicaría virtualización anidada.
    # --------------------------------------------------------

    if exists docker; then

        ok "Docker ya está instalado"
        return
    fi

    curl -fsSL https://get.docker.com |
        sudo sh

    sudo usermod -aG docker "$USER"

    sudo systemctl enable docker
    sudo systemctl start docker

    ok "Docker Engine instalado"

    warn "Cierra sesión y vuelve a entrar para usar Docker sin sudo."
}

# ============================================================
# AWS CLI
# ============================================================

install_aws_cli() {

    section "AWS CLI"

    if exists aws; then
        ok "AWS CLI ya está instalado"
        return
    fi

    if [[ "$OS" == "macos" ]]; then

        brew install awscli

        return
    fi

    case "$ARCH" in

        arm64|aarch64)
            AWS_ARCH="aarch64"
            ;;

        x86_64)
            AWS_ARCH="x86_64"
            ;;

        *)
            warn "Arquitectura no soportada automáticamente"
            return
            ;;
    esac

    TMP="$(mktemp -d)"

    curl -fsSL \
        "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" \
        -o "$TMP/aws.zip"

    unzip -q "$TMP/aws.zip" -d "$TMP"

    sudo "$TMP/aws/install"

    rm -rf "$TMP"

    ok "AWS CLI instalado"
}

# ============================================================
# TERRAFORM
# ============================================================

install_terraform() {

    section "Terraform"

    if exists terraform; then
        ok "Terraform ya está instalado"
        return
    fi

    if [[ "$OS" == "macos" ]]; then

        brew tap hashicorp/tap
        brew install hashicorp/tap/terraform

        return
    fi

    wget -O- \
        https://apt.releases.hashicorp.com/gpg |
        gpg --dearmor |
        sudo tee \
        /usr/share/keyrings/hashicorp-archive-keyring.gpg \
        >/dev/null

    echo \
        "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" |
        sudo tee \
        /etc/apt/sources.list.d/hashicorp.list \
        >/dev/null

    sudo apt-get update
    sudo apt-get install -y terraform

    ok "Terraform instalado"
}

# ============================================================
# KUBECTL
# ============================================================

install_kubectl() {

    section "kubectl"

    if exists kubectl; then
        ok "kubectl ya está instalado"
        return
    fi

    if [[ "$OS" == "macos" ]]; then

        brew install kubectl

    else

        sudo snap install kubectl --classic
    fi

    ok "kubectl instalado"
}

# ============================================================
# CLAUDE CODE
# ============================================================

install_claude() {

    section "Claude Code"

    export NVM_DIR="$HOME/.nvm"
    source "$NVM_DIR/nvm.sh"

    if exists claude; then

        ok "Claude Code ya está instalado"
        return
    fi

    npm install -g \
        @anthropic-ai/claude-code

    ok "Claude Code instalado"
}

# ============================================================
# OPENAI CODEX
# ============================================================

install_codex() {

    section "OpenAI Codex"

    export NVM_DIR="$HOME/.nvm"
    source "$NVM_DIR/nvm.sh"

    if exists codex; then

        ok "Codex ya está instalado"
        return
    fi

    npm install -g @openai/codex

    ok "Codex instalado"
}

# ============================================================
# ANTIGRAVITY
# ============================================================

install_antigravity() {

    section "Antigravity"

    if exists antigravity; then

        ok "Antigravity ya está instalado"
        return
    fi

    if [[ "$OS" == "macos" ]]; then

        if brew info --cask antigravity \
            >/dev/null 2>&1; then

            brew install --cask antigravity

            ok "Antigravity instalado"

        else

            warn "Antigravity no está disponible mediante Homebrew."
            warn "Instálalo desde su distribución oficial."
        fi

    else

        warn "Antigravity queda como instalación manual."
    fi
}

# ============================================================
# CHATGPT
# ============================================================

install_chatgpt() {

    section "ChatGPT Desktop"

    if [[ "$OS" == "macos" ]]; then

        if [[ -d "/Applications/ChatGPT.app" ]]; then

            ok "ChatGPT ya está instalado"

        else

            brew install --cask chatgpt || \
                warn "No fue posible instalar ChatGPT automáticamente."
        fi

    else

        warn "ChatGPT Desktop para Linux queda como instalación separada."
    fi
}

# ============================================================
# SHELL
# ============================================================

configure_shell() {

    section "Configurando terminal"

    if [[ "$OS" == "macos" ]]; then
        RC="$HOME/.zshrc"
    else
        RC="$HOME/.bashrc"
    fi

    touch "$RC"

    if ! grep -q \
        "# DEV-SETUP-ALIASES" \
        "$RC"; then

        cat >> "$RC" <<'EOF'

# DEV-SETUP-ALIASES

alias ll='ls -lah'

alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git pull'
alias gps='git push'

alias d='docker'
alias dc='docker compose'

alias k='kubectl'

EOF

    fi

    ok "Aliases configurados"
}

# ============================================================
# RESUMEN GITHUB
# ============================================================

show_github_accounts() {

    section "CUENTAS GITHUB"

    echo
    echo "Tus proyectos están organizados en:"
    echo
    echo "  $PROJECTS_DIR"
    echo

    for key in "$SSH_DIR"/id_ed25519_*.pub; do

        [[ -e "$key" ]] || continue

        filename="$(basename "$key")"

        alias="${filename#id_ed25519_}"
        alias="${alias%.pub}"

        echo "------------------------------------------------------------"
        echo "$alias"
        echo "------------------------------------------------------------"
        echo

        cat "$key"

        echo
    done

    echo
    echo "Agrega cada clave pública a su correspondiente cuenta GitHub."
    echo
}

# ============================================================
# RESUMEN
# ============================================================

summary() {

    section "INSTALACIÓN COMPLETADA"

    echo
    printf "%-15s %s\n" \
        "Sistema:" "$OS"

    printf "%-15s %s\n" \
        "Arquitectura:" "$ARCH"

    echo

    printf "%-15s %s\n" \
        "Git:" "$(git --version 2>/dev/null || echo '-')"

    printf "%-15s %s\n" \
        "Node:" "$(node --version 2>/dev/null || echo '-')"

    printf "%-15s %s\n" \
        "npm:" "$(npm --version 2>/dev/null || echo '-')"

    printf "%-15s %s\n" \
        "pnpm:" "$(pnpm --version 2>/dev/null || echo '-')"

    printf "%-15s %s\n" \
        "Python:" "$(python3 --version 2>/dev/null || echo '-')"

    printf "%-15s %s\n" \
        "Docker:" "$(docker --version 2>/dev/null || echo '-')"

    printf "%-15s %s\n" \
        "AWS:" "$(aws --version 2>&1 || echo '-')"

    printf "%-15s %s\n" \
        "Terraform:" "$(terraform version 2>/dev/null | head -1 || echo '-')"

    printf "%-15s %s\n" \
        "kubectl:" "$(kubectl version --client 2>/dev/null | head -1 || echo '-')"

    printf "%-15s %s\n" \
        "Claude:" "$(claude --version 2>/dev/null || echo '-')"

    printf "%-15s %s\n" \
        "Codex:" "$(codex --version 2>/dev/null || echo '-')"

    echo
    echo "============================================================"
    echo " SIGUIENTES PASOS"
    echo "============================================================"
    echo

    echo "1. Configura GitHub:"
    echo
    echo "      gh auth login"
    echo

    echo "2. Tus proyectos están en:"
    echo
    echo "      ~/Projects/<cuenta>"
    echo

    echo "3. Ejemplo de clonación:"
    echo
    echo "      cd ~/Projects/personal"
    echo "      git clone git@github-personal:usuario/repositorio.git"
    echo

    if [[ "$OS" == "ubuntu" ]]; then

        echo "4. Cierra sesión y vuelve a entrar."
        echo "   Esto habilita Docker sin sudo."
        echo
    fi

    echo "✓ Development machine ready"
    echo
}

# ============================================================
# MAIN
# ============================================================

main() {

    clear

    echo "============================================================"
    echo "               DEV MACHINE SETUP"
    echo "============================================================"

    detect_system

    install_homebrew

    install_ubuntu_base
    install_macos_base

    install_github_cli

    configure_git_accounts

    install_node

    install_java

    install_vscode
    install_vscode_extensions

    install_docker

    install_aws_cli
    install_terraform
    install_kubectl

    install_claude
    install_codex

    install_antigravity
    install_chatgpt

    configure_shell

    show_github_accounts

    summary
}

main "$@"