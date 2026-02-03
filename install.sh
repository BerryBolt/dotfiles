#!/bin/bash
# One-line bootstrap for Berry Bolt dotfiles
# Usage: curl -fsSL https://raw.githubusercontent.com/BerryBolt/dotfiles/main/install.sh | bash

set -eu
trap 'log_error "Aborted."' INT TERM

#
# Logging (with gum support and fallback)
#
log_info() {
  if command -v gum >/dev/null 2>&1; then
    gum style --foreground 75 "→ $*"
  else
    printf "\033[0;34m→ %s\033[0m\n" "$*"
  fi
}

log_success() {
  if command -v gum >/dev/null 2>&1; then
    gum style --foreground 82 "✓ $*"
  else
    printf "\033[0;32m✓ %s\033[0m\n" "$*"
  fi
}

log_error() {
  if command -v gum >/dev/null 2>&1; then
    gum style --foreground 196 "✗ $*"
  else
    printf "\033[0;31m✗ %s\033[0m\n" "$*" >&2
  fi
  exit 1
}

#
# 1. Install gum for enhanced prompts
#
if ! command -v gum >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "Installing gum..."
    brew install gum >/dev/null 2>&1
  fi
fi

echo ""
log_info "Dotfiles Bootstrap"
echo ""

#
# 2. Get 1Password token
#
if [ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]; then
  log_info "1Password service account token required"
  echo "    See: https://github.com/BerryBolt/dotfiles/blob/main/skills/1password-setup/SKILL.md"
  echo ""

  if command -v gum >/dev/null 2>&1; then
    OP_SERVICE_ACCOUNT_TOKEN=$(gum input --password --placeholder "Enter token...")
  elif [ -e /dev/tty ]; then
    printf "    Enter token: "
    read -rs OP_SERVICE_ACCOUNT_TOKEN < /dev/tty
    echo ""
  else
    log_error "No terminal available. Set OP_SERVICE_ACCOUNT_TOKEN env var."
  fi
fi

if [ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]; then
  log_error "No token provided"
fi
export OP_SERVICE_ACCOUNT_TOKEN

#
# 3. Install mise
#
if ! command -v mise >/dev/null 2>&1; then
  log_info "Installing mise..."
  curl -fsSL https://mise.run | sh
fi
export PATH="$HOME/.local/bin:$PATH"

#
# 4. Install chezmoi via mise
#
log_info "Installing chezmoi..."
mise use -g chezmoi@latest
export PATH="$HOME/.local/share/mise/shims:$PATH"

#
# 5. Update source repo if exists
#
if [ -d ~/.local/share/chezmoi/.git ]; then
  log_info "Updating dotfiles repo..."
  git -C ~/.local/share/chezmoi pull --ff-only --quiet
fi

#
# 6. Remove stale config to force template re-evaluation
#
rm -f ~/.config/chezmoi/chezmoi.toml

#
# 7. Initialize and apply
#
log_info "Applying dotfiles..."
if ! chezmoi init --apply BerryBolt/dotfiles; then
  log_error "Bootstrap failed"
fi

echo ""
log_success "Bootstrap complete"
echo "    Restart your shell: exec \$SHELL"
echo ""
