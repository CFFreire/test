#!/usr/bin/env bash
set -e

# Homebrew
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL \
    https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Apple Silicon: hacer brew disponible inmediatamente
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Brewfile embebido
BREWFILE="$(mktemp)"

cat > "$BREWFILE" <<'EOF'
brew "git"
brew "gh"
brew "wget"
brew "jq"
brew "tree"
brew "ripgrep"
brew "fzf"
brew "tmux"

brew "nvm"
brew "python"
brew "pipx"

brew "openjdk"
brew "maven"
brew "gradle"

brew "awscli"
brew "terraform"
brew "kubectl"
brew "helm"

cask "visual-studio-code"
cask "docker"
cask "chatgpt"
cask "google-chrome"
cask "iterm2"
EOF

brew bundle --file="$BREWFILE"
rm "$BREWFILE"

# Node
mkdir -p "$HOME/.nvm"

NVM_PREFIX="$(brew --prefix nvm)"

grep -q 'NVM_DIR=' "$HOME/.zshrc" 2>/dev/null || cat >> "$HOME/.zshrc" <<EOF

# NVM
export NVM_DIR="\$HOME/.nvm"
[ -s "$NVM_PREFIX/nvm.sh" ] && \. "$NVM_PREFIX/nvm.sh"
EOF

export NVM_DIR="$HOME/.nvm"
source "$NVM_PREFIX/nvm.sh"

nvm install --lts
nvm alias default 'lts/*'
nvm use default

npm install -g pnpm
npm install -g @anthropic-ai/claude-code
npm install -g @openai/codex

# Directorios
mkdir -p \
  "$HOME/Projects/personal" \
  "$HOME/Projects/work"

# Git
git config --global init.defaultBranch main
git config --global core.autocrlf input

# VS Code extensions
code --install-extension dbaeumer.vscode-eslint || true
code --install-extension esbenp.prettier-vscode || true
code --install-extension ms-python.python || true
code --install-extension ms-azuretools.vscode-docker || true
code --install-extension eamodio.gitlens || true
code --install-extension redhat.vscode-yaml || true
code --install-extension hashicorp.terraform || true
code --install-extension ms-vscode-remote.remote-ssh || true
code --install-extension ms-vscode-remote.remote-containers || true

echo
echo "======================================"
echo " Mac development environment ready"
echo "======================================"
