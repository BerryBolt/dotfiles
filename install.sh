#!/bin/sh
# One-line bootstrap for Berry Bolt dotfiles
# Usage: curl -fsSL https://raw.githubusercontent.com/BerryBolt/dotfiles/main/install.sh | sh

set -e

echo "=== Dotfiles Bootstrap ==="

# Prompt for token if not set (avoids exposing in shell history)
if [ -z "$OP_SERVICE_ACCOUNT_TOKEN" ]; then
    echo "1Password service account token required."
    echo "See: https://github.com/BerryBolt/dotfiles/blob/main/skills/1password-setup/SKILL.md"
    echo ""
    printf "Enter token: "
    stty -echo < /dev/tty
    read OP_SERVICE_ACCOUNT_TOKEN < /dev/tty
    stty echo < /dev/tty
    echo ""
    export OP_SERVICE_ACCOUNT_TOKEN
fi

if [ -z "$OP_SERVICE_ACCOUNT_TOKEN" ]; then
    echo "Error: No token provided"
    exit 1
fi

# Install mise if not present
if ! command -v mise > /dev/null 2>&1; then
    echo "Installing mise..."
    curl -fsSL https://mise.run | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

# Activate mise
eval "$(~/.local/bin/mise activate sh)"

# Install chezmoi via mise
echo "Installing chezmoi..."
mise use -g chezmoi@latest

# Bootstrap dotfiles
echo "Bootstrapping dotfiles..."
chezmoi init --apply BerryBolt/dotfiles

echo ""
echo "=== Bootstrap complete ==="
echo "Restart your shell: exec \$SHELL"
