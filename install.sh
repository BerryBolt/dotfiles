#!/usr/bin/env bash
# One-line bootstrap for Berry Bolt dotfiles
# Usage: curl -fsSL https://raw.githubusercontent.com/BerryBolt/dotfiles/main/install.sh | bash

set -e
trap 'echo ""; echo "Aborted."; exit 1' INT TERM

echo "=== Dotfiles Bootstrap ==="

#
# 1. Get 1Password token (prompt if not set)
#
if [ -z "$OP_SERVICE_ACCOUNT_TOKEN" ]; then
    if [ ! -e /dev/tty ]; then
        echo "Error: No terminal available and OP_SERVICE_ACCOUNT_TOKEN not set"
        exit 1
    fi
    echo "1Password service account token required."
    echo "See: https://github.com/BerryBolt/dotfiles/blob/main/skills/1password-setup/SKILL.md"
    echo ""
    printf "Enter token: "
    read -rs OP_SERVICE_ACCOUNT_TOKEN < /dev/tty
    echo ""
fi

if [ -z "$OP_SERVICE_ACCOUNT_TOKEN" ]; then
    echo "Error: No token provided"
    exit 1
fi
export OP_SERVICE_ACCOUNT_TOKEN

#
# 2. Install mise (if not already installed)
#
if ! command -v mise > /dev/null 2>&1; then
    echo "Installing mise..."
    curl -fsSL https://mise.run | sh
fi
# Ensure mise is in PATH (handles fresh install)
export PATH="$HOME/.local/bin:$PATH"

#
# 3. Install chezmoi via mise
#
echo "Installing chezmoi..."
mise use -g chezmoi@latest
export PATH="$HOME/.local/share/mise/shims:$PATH"

#
# 4. Update source repo if it exists (chezmoi init won't pull)
#
if [ -d ~/.local/share/chezmoi/.git ]; then
    echo "Updating dotfiles repo..."
    git -C ~/.local/share/chezmoi pull --ff-only --quiet
fi

#
# 5. Remove old config to force template re-evaluation
#    (Otherwise chezmoi uses stale config, ignoring env var and new fields)
#
rm -f ~/.config/chezmoi/chezmoi.toml

#
# 6. Initialize and apply
#    - Clones repo if source doesn't exist
#    - Regenerates config from template (uses OP_SERVICE_ACCOUNT_TOKEN env var)
#    - Applies dotfiles
#
echo "Applying dotfiles..."
if ! chezmoi init --apply BerryBolt/dotfiles; then
    echo ""
    echo "=== Bootstrap failed or aborted ==="
    exit 1
fi

echo ""
echo "=== Bootstrap complete ==="
echo "Restart your shell: exec \$SHELL"
