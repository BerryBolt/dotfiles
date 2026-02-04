#!/bin/sh
# One-line bootstrap for Berry Bolt dotfiles
# Usage:
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/BerryBolt/dotfiles/main/install.sh)"
#   # or
#   curl -fsSL https://raw.githubusercontent.com/BerryBolt/dotfiles/main/install.sh | sh

set -eu

SCRIPT_URL="https://raw.githubusercontent.com/BerryBolt/dotfiles/main/install.sh"
NONINTERACTIVE="${CHEZMOI_NONINTERACTIVE:-${NONINTERACTIVE:-}}"

usage() {
  cat <<'EOF'
Usage:
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/BerryBolt/dotfiles/main/install.sh)"
  # or
  curl -fsSL https://raw.githubusercontent.com/BerryBolt/dotfiles/main/install.sh | sh

Env overrides:
  CHEZMOI_AGENT_NAME=...
  CHEZMOI_AGENT_EMAIL=...
  CHEZMOI_AGENT_HANDLE_GITHUB=...
  CHEZMOI_OP_VAULT=...
  OP_SERVICE_ACCOUNT_TOKEN=...
  CHEZMOI_AI_CLI=claude|codex|none

Optional:
  CHEZMOI_NONINTERACTIVE=1  # disable prompts (requires all env vars)
  --non-interactive         # same as above
EOF
}

for arg in "$@"; do
  case "$arg" in
    -h|--help)
      usage
      exit 0
      ;;
    --non-interactive|--unattended)
      NONINTERACTIVE=1
      ;;
  esac
done

abort() {
  stty echo < /dev/tty 2>/dev/null || true
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
      "BERRY BOLT DOTFILES" "guided setup console"
  else
    echo ""
    printf "=====================================\n"
    printf " BERRY BOLT DOTFILES\n"
    printf " guided setup console\n"
    printf "=====================================\n"
    echo ""
  fi
}

require_cmd() {
  cmd=$1
  hint=${2-}
  if ! command -v "$cmd" >/dev/null 2>&1; then
    if [ -n "$hint" ]; then
      log_error "Missing required command: $cmd. $hint"
    else
      log_error "Missing required command: $cmd"
    fi
  fi
}

TTY_DEV=""

detect_tty() {
  TTY_DEV=""
  if command -v tty >/dev/null 2>&1; then
    if tty >/dev/null 2>&1; then
      TTY_DEV="/dev/tty"
      return
    fi
  fi
  if [ -r /dev/tty ]; then
    TTY_DEV="/dev/tty"
    return
  fi
  if [ -t 0 ]; then
    TTY_DEV="/dev/stdin"
  fi
}

has_tty() {
  [ -n "$TTY_DEV" ]
}

require_tty() {
  detect_tty
  if ! has_tty; then
    log_error "No terminal detected.
This installer is interactive. Run it from a TTY or set env vars.
Tip: sh -c \"\$(curl -fsSL $SCRIPT_URL)\""
  fi
}

is_blank() {
  case ${1-} in
    *[![:space:]]*) return 1 ;;
    *) return 0 ;;
  esac
}

ensure_mise_tool() {
  tool=$1
  spec=${2-"$tool@latest"}
  binary=${3-"$tool"}
  label=${4-"$tool"}

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

PROMPT_VALUE=""

mask_token() {
  printf '%s' "$1" | awk '{ l=length($0); if (l<=4) print $0; else print "..." substr($0,l-3) }'
}

normalize_ai_cli() {
  value=${1-}
  if [ -n "$value" ]; then
    value=$(printf "%s" "$value" | tr '[:upper:]' '[:lower:]')
  fi
  case "$value" in
    claude|claude-code) printf "%s" "claude" ;;
    codex|none) printf "%s" "$value" ;;
    *) printf "%s" "" ;;
  esac
}

prompt_string() {
  label=$1
  placeholder=$2
  current=$3
  input=""

  require_tty

  while :; do
    log_info "$label"
    if [ -n "$current" ]; then
      echo "    Current: $current"
      echo "    Leave blank to keep."
    fi

    if command -v gum >/dev/null 2>&1; then
      if [ -n "$placeholder" ]; then
        input=$(gum input --placeholder "$placeholder" < "$TTY_DEV") || abort
      else
        input=$(gum input < "$TTY_DEV") || abort
      fi
    else
      printf "    %s: " "$label"
      read -r input < "$TTY_DEV" || abort
    fi

    if is_blank "$input" && [ -n "$current" ]; then
      input=$current
    fi

    if is_blank "$input"; then
      log_info "Value required. Try again."
      continue
    fi

    PROMPT_VALUE=$input
    echo "    ✓ $label: $PROMPT_VALUE"
    break
  done
}

prompt_secret() {
  label=$1
  current=$2
  input=""

  require_tty

  while :; do
    log_info "$label"
    if [ -n "$current" ]; then
      echo "    Token already set. Leave blank to keep."
    fi

    if command -v gum >/dev/null 2>&1; then
      input=$(gum input --password --placeholder "Enter token..." < "$TTY_DEV") || abort
    else
      printf "    Enter token: "
      stty -echo < "$TTY_DEV" 2>/dev/null || true
      read -r input < "$TTY_DEV" || abort
      stty echo < "$TTY_DEV" 2>/dev/null || true
      echo ""
    fi

    if is_blank "$input" && [ -n "$current" ]; then
      input=$current
    fi

    if is_blank "$input"; then
      log_info "Token required. Try again."
      continue
    fi

    PROMPT_VALUE=$input
    tail=$(mask_token "$PROMPT_VALUE")
    echo "    ✓ Token set ($tail)"
    break
  done
}

prompt_ai_cli() {
  current=$1
  label="AI CLI to install"
  choice=""

  require_tty

  while :; do
    log_info "$label"
    echo "    Choose which AI CLI to install."
    echo "    claude = Anthropic, codex = OpenAI, none = skip."
    if [ -n "$current" ]; then
      echo "    Current: $current"
      echo "    Select keep current to leave unchanged."
    fi

    if command -v gum >/dev/null 2>&1; then
      if [ -n "$current" ]; then
        choice=$(gum choose --header "$label" \
          "keep current ($current)" \
          "claude (Anthropic)" \
          "codex (OpenAI)" \
          "none" < "$TTY_DEV") || abort
      else
        choice=$(gum choose --header "$label" \
          "claude (Anthropic)" \
          "codex (OpenAI)" \
          "none" < "$TTY_DEV") || abort
      fi
    else
      if [ -n "$current" ]; then
        echo "    0) keep current ($current)"
      fi
      echo "    1) claude (Anthropic)"
      echo "    2) codex (OpenAI)"
      echo "    3) none"
      printf "    Enter choice: "
      read -r selection < "$TTY_DEV" || abort
      if is_blank "$selection" && [ -n "$current" ]; then
        choice="keep"
      else
        case "$selection" in
          0) choice="keep" ;;
          1) choice="claude" ;;
          2) choice="codex" ;;
          3) choice="none" ;;
          *) choice="invalid" ;;
        esac
      fi
      case "$choice" in
        keep) choice="$current" ;;
        invalid)
          log_info "Invalid choice. Try again."
          continue
          ;;
      esac
    fi

    case "$choice" in
      "keep current ("*) choice="$current" ;;
      claude*) choice="claude" ;;
      codex*) choice="codex" ;;
      none*) choice="none" ;;
      *)
        log_info "Invalid choice. Try again."
        continue
        ;;
    esac

    PROMPT_VALUE=$choice
    echo "    ✓ $label: $PROMPT_VALUE"
    break
  done
}

review_and_edit() {
  choice=""
  require_tty
  while :; do
    echo ""
    log_info "Review your choices"
    echo "    Agent name: $AGENT_NAME"
    echo "    Agent email: $AGENT_EMAIL"
    echo "    GitHub handle: $AGENT_HANDLE_GITHUB"
    echo "    1Password vault: $OP_VAULT"
    echo "    AI CLI: $CHEZMOI_AI_CLI"
    if ! is_blank "$OP_SERVICE_ACCOUNT_TOKEN"; then
      tail=$(mask_token "$OP_SERVICE_ACCOUNT_TOKEN")
      echo "    Token: set ($tail)"
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
        "Edit AI CLI" < "$TTY_DEV") || abort
    else
      echo "    1) Confirm"
      echo "    2) Edit agent name"
      echo "    3) Edit agent email"
      echo "    4) Edit GitHub handle"
      echo "    5) Edit 1Password vault"
      echo "    6) Edit token"
      echo "    7) Edit AI CLI"
      printf "    Enter choice [1-7]: "
      read -r selection < "$TTY_DEV" || abort
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
        if is_blank "$OP_SERVICE_ACCOUNT_TOKEN"; then
          log_info "1Password token required before continuing"
          prompt_secret "1Password service account token" "$OP_SERVICE_ACCOUNT_TOKEN"
          OP_SERVICE_ACCOUNT_TOKEN=$PROMPT_VALUE
          continue
        fi
        break
        ;;
      "Edit agent name")
        prompt_string "Agent name" "Berry Bolt" "$AGENT_NAME"
        AGENT_NAME=$PROMPT_VALUE
        ;;
      "Edit agent email")
        prompt_string "Agent email" "you@example.com" "$AGENT_EMAIL"
        AGENT_EMAIL=$PROMPT_VALUE
        ;;
      "Edit GitHub handle")
        prompt_string "GitHub handle" "BerryBolt" "$AGENT_HANDLE_GITHUB"
        AGENT_HANDLE_GITHUB=$PROMPT_VALUE
        ;;
      "Edit 1Password vault")
        prompt_string "1Password vault name" "Berry Bolt" "$OP_VAULT"
        OP_VAULT=$PROMPT_VALUE
        ;;
      "Edit token")
        prompt_secret "1Password service account token" "$OP_SERVICE_ACCOUNT_TOKEN"
        OP_SERVICE_ACCOUNT_TOKEN=$PROMPT_VALUE
        ;;
      "Edit AI CLI")
        prompt_ai_cli "$CHEZMOI_AI_CLI"
        CHEZMOI_AI_CLI=$PROMPT_VALUE
        ;;
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

log_info "Answer a few prompts. You can review and edit before apply."

#
# 2. Collect setup inputs
#
AGENT_NAME="${CHEZMOI_AGENT_NAME:-}"
AGENT_EMAIL="${CHEZMOI_AGENT_EMAIL:-}"
AGENT_HANDLE_GITHUB="${CHEZMOI_AGENT_HANDLE_GITHUB:-}"
OP_VAULT="${CHEZMOI_OP_VAULT:-}"
OP_SERVICE_ACCOUNT_TOKEN="${OP_SERVICE_ACCOUNT_TOKEN:-}"
if is_blank "$OP_SERVICE_ACCOUNT_TOKEN"; then
  OP_SERVICE_ACCOUNT_TOKEN=""
fi

CHEZMOI_AI_CLI="$(normalize_ai_cli "${CHEZMOI_AI_CLI:-}")"

detect_tty

if [ -n "$NONINTERACTIVE" ]; then
  missing=""
  is_blank "$AGENT_NAME" && missing="$missing CHEZMOI_AGENT_NAME"
  is_blank "$AGENT_EMAIL" && missing="$missing CHEZMOI_AGENT_EMAIL"
  is_blank "$AGENT_HANDLE_GITHUB" && missing="$missing CHEZMOI_AGENT_HANDLE_GITHUB"
  is_blank "$OP_VAULT" && missing="$missing CHEZMOI_OP_VAULT"
  is_blank "$OP_SERVICE_ACCOUNT_TOKEN" && missing="$missing OP_SERVICE_ACCOUNT_TOKEN"
  is_blank "$CHEZMOI_AI_CLI" && missing="$missing CHEZMOI_AI_CLI"

  if [ -n "$missing" ]; then
    log_error "Non-interactive mode requires env vars:$missing"
  fi
elif ! has_tty; then
  missing=""
  is_blank "$AGENT_NAME" && missing="$missing CHEZMOI_AGENT_NAME"
  is_blank "$AGENT_EMAIL" && missing="$missing CHEZMOI_AGENT_EMAIL"
  is_blank "$AGENT_HANDLE_GITHUB" && missing="$missing CHEZMOI_AGENT_HANDLE_GITHUB"
  is_blank "$OP_VAULT" && missing="$missing CHEZMOI_OP_VAULT"
  is_blank "$OP_SERVICE_ACCOUNT_TOKEN" && missing="$missing OP_SERVICE_ACCOUNT_TOKEN"
  is_blank "$CHEZMOI_AI_CLI" && missing="$missing CHEZMOI_AI_CLI"

  if [ -n "$missing" ]; then
    log_error "No terminal detected.
Set env vars:$missing
Tip: sh -c \"\$(curl -fsSL $SCRIPT_URL)\""
  fi
else
  if is_blank "$AGENT_NAME"; then
    prompt_string "Agent name" "Berry Bolt" "$AGENT_NAME"
    AGENT_NAME=$PROMPT_VALUE
  fi
  if is_blank "$AGENT_EMAIL"; then
    prompt_string "Agent email" "you@example.com" "$AGENT_EMAIL"
    AGENT_EMAIL=$PROMPT_VALUE
  fi
  if is_blank "$AGENT_HANDLE_GITHUB"; then
    prompt_string "GitHub handle" "BerryBolt" "$AGENT_HANDLE_GITHUB"
    AGENT_HANDLE_GITHUB=$PROMPT_VALUE
  fi
  if is_blank "$OP_VAULT"; then
    prompt_string "1Password vault name" "Berry Bolt" "$OP_VAULT"
    OP_VAULT=$PROMPT_VALUE
  fi
  if is_blank "$OP_SERVICE_ACCOUNT_TOKEN"; then
    echo "    See: https://github.com/BerryBolt/dotfiles/blob/main/skills/1password-setup/SKILL.md"
    echo ""
    prompt_secret "1Password service account token" "$OP_SERVICE_ACCOUNT_TOKEN"
    OP_SERVICE_ACCOUNT_TOKEN=$PROMPT_VALUE
  else
    log_info "1Password token detected (you can edit in review)"
  fi
  if is_blank "$CHEZMOI_AI_CLI"; then
    prompt_ai_cli "$CHEZMOI_AI_CLI"
    CHEZMOI_AI_CLI=$PROMPT_VALUE
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
