#!/bin/bash
# One-line bootstrap for Berry Bolt dotfiles
# Usage: curl -fsSL https://raw.githubusercontent.com/BerryBolt/dotfiles/main/install.sh | bash

set -euo pipefail

abort() {
  echo ""
  printf "\033[0;31m✗ Aborted.\033[0m\n" >&2
  exit 130
}
trap abort INT TERM

#
# Logging (with gum support and fallback)
#
log_info() {
  if command -v gum >/dev/null 2>&1; then
    gum style --foreground 75 --bold "→ $*"
  else
    printf "\033[0;34m→ %s\033[0m\n" "$*"
  fi
}

log_success() {
  if command -v gum >/dev/null 2>&1; then
    gum style --foreground 82 --bold "✓ $*"
  else
    printf "\033[0;32m✓ %s\033[0m\n" "$*"
  fi
}

log_error() {
  if command -v gum >/dev/null 2>&1; then
    gum style --foreground 196 --bold "✗ $*"
  else
    printf "\033[0;31m✗ %s\033[0m\n" "$*" >&2
  fi
  exit 1
}

log_header() {
  if command -v gum >/dev/null 2>&1; then
    gum style --border rounded --padding "1 2" --margin "1 0" --align center --bold \
      --foreground 212 --border-foreground 57 \
      "BERRY BOLT DOTFILES" "bootstrap protocol v1"
  else
    echo ""
    printf "=====================================\n"
    printf " BERRY BOLT DOTFILES\n"
    printf " bootstrap protocol v1\n"
    printf "=====================================\n"
    echo ""
  fi
}

require_cmd() {
  local cmd="$1"
  local hint="${2:-}"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    if [ -n "$hint" ]; then
      log_error "Missing required command: $cmd. $hint"
    else
      log_error "Missing required command: $cmd"
    fi
  fi
}

#
# 1. Install gum for enhanced prompts
#
if ! command -v gum >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    log_info "Installing gum..."
    brew install gum >/dev/null 2>&1
  fi
fi

log_header
require_cmd curl "Install curl and re-run."

#
# 2. Get 1Password token
#
if [ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]; then
  log_info "1Password service account token required"
  echo "    See: https://github.com/BerryBolt/dotfiles/blob/main/skills/1password-setup/SKILL.md"
  echo ""

  if command -v gum >/dev/null 2>&1; then
    OP_SERVICE_ACCOUNT_TOKEN=$(gum input --password --placeholder "Enter token...") || abort
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
# 3. Select AI CLI
#
if [ -z "${CHEZMOI_AI_CLI:-}" ]; then
  log_info "Select AI CLI to install"
  echo ""
  if command -v gum >/dev/null 2>&1; then
    CHEZMOI_AI_CLI=$(gum choose "claude" "codex" "none") || abort
  elif [ -e /dev/tty ]; then
    echo "    1) claude"
    echo "    2) codex"
    echo "    3) none"
    printf "    Enter choice [1-3]: "
    read -r choice < /dev/tty
    case "$choice" in
      1) CHEZMOI_AI_CLI="claude" ;;
      2) CHEZMOI_AI_CLI="codex" ;;
      *) CHEZMOI_AI_CLI="none" ;;
    esac
  else
    log_info "No terminal available; defaulting to 'none'"
    CHEZMOI_AI_CLI="none"
  fi
fi
export CHEZMOI_AI_CLI

#
# 3. Configure 1Password mode for service accounts (before init)
#
export CHEZMOI_ONEPASSWORD_MODE="service"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi"
config_file="$config_dir/chezmoi.toml"
rm -f "$config_file"
mkdir -p "$config_dir"
cat > "$config_file" <<'EOF'
[onepassword]
  mode = "service"
EOF

#
# 4. Install mise
#
if ! command -v mise >/dev/null 2>&1; then
  log_info "Installing mise..."
  curl -fsSL https://mise.run | sh
fi
export PATH="$HOME/.local/bin:$PATH"
if ! command -v mise >/dev/null 2>&1; then
  log_error "mise installation failed or not on PATH"
fi

#
# 5. Install chezmoi via mise
#
log_info "Installing chezmoi..."
mise use -g chezmoi@latest
export PATH="$HOME/.local/share/mise/shims:$PATH"
if ! command -v chezmoi >/dev/null 2>&1; then
  log_error "chezmoi installation failed or not on PATH"
fi

#
# 6. Update source repo if exists
#
if [ -d ~/.local/share/chezmoi/.git ]; then
  log_info "Updating dotfiles repo..."
  if command -v git >/dev/null 2>&1; then
    if ! git -C ~/.local/share/chezmoi pull --ff-only --quiet; then
      log_error "git pull failed. Resolve local changes and re-run."
    fi
  else
    log_error "git is required to update the dotfiles repo"
  fi
fi

#
# 7. Initialize and apply
#
log_info "Applying dotfiles..."
require_cmd git "Install git and re-run."
if ! chezmoi init --apply BerryBolt/dotfiles; then
  log_error "Bootstrap failed"
fi

echo ""
log_success "Bootstrap complete"
echo "    Restart your shell: exec \$SHELL"
echo ""
