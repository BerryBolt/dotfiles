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

is_tty() {
  [ -r /dev/tty ]
}

ensure_mise_tool() {
  local tool="$1"
  local spec="${2:-${1}@latest}"
  local binary="${3:-$1}"
  local label="${4:-$1}"

  if ! command -v "$binary" >/dev/null 2>&1; then
    log_info "Installing ${label} via mise..."
    if ! mise use -g "$spec" >/dev/null 2>&1; then
      log_error "Failed to install ${label} via mise"
    fi
  fi

  if ! command -v "$binary" >/dev/null 2>&1; then
    log_error "${label} not found. Install ${label} and re-run."
  fi
}

prompt_string() {
  local label="$1"
  local varname="$2"
  local placeholder="${3:-}"
  local current="${!varname:-}"
  local input=""

  if ! is_tty; then
    log_error "No terminal available. Set $varname env var."
  fi

  log_info "$label"
  if [ -n "$current" ]; then
    echo "    Current: $current"
    echo "    Leave blank to keep."
  fi

  if command -v gum >/dev/null 2>&1; then
    if [ -n "$placeholder" ]; then
      input=$(gum input --placeholder "$placeholder" < /dev/tty) || abort
    else
      input=$(gum input < /dev/tty) || abort
    fi
  else
    printf "    %s: " "$label"
    read -r input < /dev/tty
  fi

  if [ -z "$input" ] && [ -n "$current" ]; then
    input="$current"
  fi

  if [ -z "$input" ]; then
    log_error "$label is required"
  fi

  printf -v "$varname" "%s" "$input"
  echo "    ✓ $label: ${!varname}"
}

prompt_secret() {
  local label="$1"
  local varname="$2"
  local current="${!varname:-}"
  local input=""

  if ! is_tty; then
    log_error "No terminal available. Set $varname env var."
  fi

  log_info "$label"
  if [ -n "$current" ]; then
    echo "    Token already set. Leave blank to keep."
  fi

  if command -v gum >/dev/null 2>&1; then
    input=$(gum input --password --placeholder "Enter token..." < /dev/tty) || abort
  else
    printf "    Enter token: "
    read -rs input < /dev/tty
    echo ""
  fi

  if [ -z "$input" ] && [ -n "$current" ]; then
    input="$current"
  fi

  if [ -z "$input" ]; then
    log_error "$label is required"
  fi

  printf -v "$varname" "%s" "$input"
  echo "    ✓ Token captured"
}

prompt_choice() {
  local label="$1"
  local varname="$2"
  shift 2
  local choices=("$@")
  local current="${!varname:-}"
  local input=""

  if ! is_tty; then
    log_error "No terminal available. Set $varname env var."
  fi

  log_info "$label"
  if [ -n "$current" ]; then
    echo "    Current: $current"
    echo "    Press Enter to keep current selection."
    local reordered=("$current")
    local choice
    for choice in "${choices[@]}"; do
      [ "$choice" = "$current" ] && continue
      reordered+=("$choice")
    done
    choices=("${reordered[@]}")
  fi

  if command -v gum >/dev/null 2>&1; then
    input=$(gum choose --header "$label" "${choices[@]}" < /dev/tty) || abort
  else
    local i=1
    local choice
    for choice in "${choices[@]}"; do
      echo "    $i) $choice"
      i=$((i + 1))
    done
    printf "    Enter choice [1-%d]: " "${#choices[@]}"
    read -r selection < /dev/tty
    if [ -z "$selection" ] && [ -n "$current" ]; then
      input="$current"
    else
      case "$selection" in
        1) input="${choices[0]}" ;;
        2) input="${choices[1]}" ;;
        3) input="${choices[2]}" ;;
        *) input="${choices[$((${#choices[@]} - 1))]}" ;;
      esac
    fi
  fi

  if [ -z "$input" ]; then
    log_error "$label is required"
  fi

  printf -v "$varname" "%s" "$input"
  echo "    ✓ $label: ${!varname}"
}

review_and_edit() {
  local choice=""
  while :; do
    echo ""
    log_info "Review your choices"
    echo "    Agent name: $AGENT_NAME"
    echo "    Agent email: $AGENT_EMAIL"
    echo "    GitHub handle: $AGENT_HANDLE_GITHUB"
    echo "    1Password vault: $OP_VAULT"
    echo "    AI CLI: $CHEZMOI_AI_CLI"
    if [ -n "$OP_SERVICE_ACCOUNT_TOKEN" ]; then
      local tail="${OP_SERVICE_ACCOUNT_TOKEN: -4}"
      if [ "${#OP_SERVICE_ACCOUNT_TOKEN}" -le 4 ]; then
        echo "    Token: set (${tail})"
      else
        echo "    Token: set (…${tail})"
      fi
    else
      echo "    Token: missing"
    fi
    echo ""

    if command -v gum >/dev/null 2>&1; then
      choice=$(gum choose --header "Review & edit" \
        "Confirm" \
        "Edit agent name" \
        "Edit agent email" \
        "Edit GitHub handle" \
        "Edit 1Password vault" \
        "Edit token" \
        "Edit AI CLI" < /dev/tty) || abort
    else
      echo "    1) Confirm"
      echo "    2) Edit agent name"
      echo "    3) Edit agent email"
      echo "    4) Edit GitHub handle"
      echo "    5) Edit 1Password vault"
      echo "    6) Edit token"
      echo "    7) Edit AI CLI"
      printf "    Enter choice [1-7]: "
      read -r selection < /dev/tty
      case "$selection" in
        1) choice="Confirm" ;;
        2) choice="Edit agent name" ;;
        3) choice="Edit agent email" ;;
        4) choice="Edit GitHub handle" ;;
        5) choice="Edit 1Password vault" ;;
        6) choice="Edit token" ;;
        7) choice="Edit AI CLI" ;;
        *) choice="Confirm" ;;
      esac
    fi

    case "$choice" in
      "Confirm")
        if [ -z "$OP_SERVICE_ACCOUNT_TOKEN" ]; then
          log_info "1Password token required before continuing"
          prompt_secret "1Password service account token" OP_SERVICE_ACCOUNT_TOKEN
          continue
        fi
        break
        ;;
      "Edit agent name") prompt_string "Agent name" AGENT_NAME "Berry Bolt" ;;
      "Edit agent email") prompt_string "Agent email" AGENT_EMAIL "you@example.com" ;;
      "Edit GitHub handle") prompt_string "GitHub handle" AGENT_HANDLE_GITHUB "BerryBolt" ;;
      "Edit 1Password vault") prompt_string "1Password vault name" OP_VAULT "Berry Bolt" ;;
      "Edit token") prompt_secret "1Password service account token" OP_SERVICE_ACCOUNT_TOKEN ;;
      "Edit AI CLI") prompt_choice "AI CLI to install" CHEZMOI_AI_CLI "claude" "codex" "none" ;;
    esac
  done
}

require_cmd curl "Install curl and re-run."

#
# 1. Install mise
#
if ! command -v mise >/dev/null 2>&1; then
  log_info "Installing mise..."
  curl -fsSL https://mise.run | sh
fi
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.local/share/mise/shims:$PATH"
if ! command -v mise >/dev/null 2>&1; then
  log_error "mise installation failed or not on PATH"
fi

# Optional: install gum via mise for enhanced prompts
if ! command -v gum >/dev/null 2>&1; then
  if ! mise use -g gum@latest >/dev/null 2>&1; then
    log_info "gum not available via mise; continuing without it."
  fi
fi

log_header

#
# 2. Collect setup inputs
#
AGENT_NAME="${CHEZMOI_AGENT_NAME:-}"
AGENT_EMAIL="${CHEZMOI_AGENT_EMAIL:-}"
AGENT_HANDLE_GITHUB="${CHEZMOI_AGENT_HANDLE_GITHUB:-}"
OP_VAULT="${CHEZMOI_OP_VAULT:-}"
OP_SERVICE_ACCOUNT_TOKEN="${OP_SERVICE_ACCOUNT_TOKEN:-}"

ai_cli_env="${CHEZMOI_AI_CLI:-}"
if [ -n "$ai_cli_env" ]; then
  ai_cli_env="$(printf "%s" "$ai_cli_env" | tr '[:upper:]' '[:lower:]')"
fi
case "$ai_cli_env" in
  claude|claude-code) CHEZMOI_AI_CLI="claude" ;;
  codex|none) CHEZMOI_AI_CLI="$ai_cli_env" ;;
  *) CHEZMOI_AI_CLI="" ;;
esac

if ! is_tty; then
  missing=()
  [ -z "$AGENT_NAME" ] && missing+=("CHEZMOI_AGENT_NAME")
  [ -z "$AGENT_EMAIL" ] && missing+=("CHEZMOI_AGENT_EMAIL")
  [ -z "$AGENT_HANDLE_GITHUB" ] && missing+=("CHEZMOI_AGENT_HANDLE_GITHUB")
  [ -z "$OP_VAULT" ] && missing+=("CHEZMOI_OP_VAULT")
  [ -z "$OP_SERVICE_ACCOUNT_TOKEN" ] && missing+=("OP_SERVICE_ACCOUNT_TOKEN")

  if [ "${#missing[@]}" -gt 0 ]; then
    log_error "No terminal available. Set env vars: ${missing[*]}"
  fi

  if [ -z "$CHEZMOI_AI_CLI" ]; then
    CHEZMOI_AI_CLI="none"
  fi
else
  if [ -z "$AGENT_NAME" ]; then
    prompt_string "Agent name" AGENT_NAME "Berry Bolt"
  fi
  if [ -z "$AGENT_EMAIL" ]; then
    prompt_string "Agent email" AGENT_EMAIL "you@example.com"
  fi
  if [ -z "$AGENT_HANDLE_GITHUB" ]; then
    prompt_string "GitHub handle" AGENT_HANDLE_GITHUB "BerryBolt"
  fi
  if [ -z "$OP_VAULT" ]; then
    prompt_string "1Password vault name" OP_VAULT "Berry Bolt"
  fi
  if [ -z "$OP_SERVICE_ACCOUNT_TOKEN" ]; then
    echo "    See: https://github.com/BerryBolt/dotfiles/blob/main/skills/1password-setup/SKILL.md"
    echo ""
    prompt_secret "1Password service account token" OP_SERVICE_ACCOUNT_TOKEN
  else
    log_info "1Password token detected (you can edit in review)"
  fi
  if [ -z "$CHEZMOI_AI_CLI" ]; then
    prompt_choice "AI CLI to install" CHEZMOI_AI_CLI "claude" "codex" "none"
  fi

  review_and_edit
fi

export CHEZMOI_AGENT_NAME="$AGENT_NAME"
export CHEZMOI_AGENT_EMAIL="$AGENT_EMAIL"
export CHEZMOI_AGENT_HANDLE_GITHUB="$AGENT_HANDLE_GITHUB"
export CHEZMOI_OP_VAULT="$OP_VAULT"
export OP_SERVICE_ACCOUNT_TOKEN
export CHEZMOI_AI_CLI

#
# 4. Configure 1Password mode for service accounts (before init)
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
# 5. Install chezmoi via mise
#
log_info "Installing chezmoi..."
ensure_mise_tool "chezmoi" "chezmoi@latest" "chezmoi" "chezmoi"

#
# 6. Install 1Password CLI (required for onepasswordRead)
#
ensure_mise_tool "1password-cli" "1password-cli@latest" "op" "1Password CLI (op)"

#
# 7. Ensure git (required for update and init)
#
ensure_mise_tool "git" "git@latest" "git" "git"

#
# 8. Update source repo if exists
#
if [ -d ~/.local/share/chezmoi/.git ]; then
  log_info "Updating dotfiles repo..."
  if ! git -C ~/.local/share/chezmoi pull --ff-only --quiet; then
    log_error "git pull failed. Resolve local changes and re-run."
  fi
fi

#
# 9. Initialize and apply
#
log_info "Applying dotfiles..."
if ! chezmoi init --apply BerryBolt/dotfiles; then
  log_error "Bootstrap failed"
fi

echo ""
log_success "Bootstrap complete"
echo "    Restart your shell: exec \$SHELL"
echo ""
