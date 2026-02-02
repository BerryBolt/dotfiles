#!/usr/bin/env bash
# One-line bootstrap for Berry Bolt dotfiles
# Usage: curl -fsSL https://raw.githubusercontent.com/BerryBolt/dotfiles/main/install.sh | bash

set -e

# Exit cleanly on Ctrl+C
trap 'echo ""; echo "Aborted."; exit 1' INT TERM

echo "=== Dotfiles Bootstrap ==="

# Prompt for token if not set (read -s requires bash, hides input)
if [ -z "$OP_SERVICE_ACCOUNT_TOKEN" ]; then
    if [ ! -t 0 ] && [ ! -e /dev/tty ]; then
        echo "Error: No terminal available and OP_SERVICE_ACCOUNT_TOKEN not set"
        echo "Set the env var first, then re-run."
        exit 1
    fi
    echo "1Password service account token required."
    echo "See: https://github.com/BerryBolt/dotfiles/blob/main/skills/1password-setup/SKILL.md"
    echo ""
    printf "Enter token: "
    read -rs OP_SERVICE_ACCOUNT_TOKEN < /dev/tty
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
eval "$(~/.local/bin/mise activate bash)"

# Install chezmoi via mise
echo "Installing chezmoi..."
mise use -g chezmoi@latest

# Bootstrap dotfiles
echo "Bootstrapping dotfiles..."
chezmoi init --apply BerryBolt/dotfiles

echo ""
echo "=== Bootstrap complete ==="
echo "Restart your shell: exec \$SHELL"
