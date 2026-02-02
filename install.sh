#!/bin/sh
# One-line bootstrap for Berry Bolt dotfiles
# Usage: curl -fsSL https://raw.githubusercontent.com/BerryBolt/dotfiles/main/install.sh | sh

set -e

echo "=== Dotfiles Bootstrap ==="

# Check for required env var
if [ -z "$OP_SERVICE_ACCOUNT_TOKEN" ]; then
    echo "Error: OP_SERVICE_ACCOUNT_TOKEN not set"
    echo ""
    echo "Set it first:"
    echo "  export OP_SERVICE_ACCOUNT_TOKEN=\"<your-token>\""
    echo ""
    echo "See: https://github.com/BerryBolt/dotfiles/blob/main/skills/1password-setup/SKILL.md"
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
