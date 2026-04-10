#!/usr/bin/env bash
# One-line bootstrap for Berry Bolt dotfiles
# Usage:
#   curl -fsSL https://berrybolt.bot/install.sh | bash

set -euo pipefail

SCRIPT_URL="https://berrybolt.bot/install.sh"
NONINTERACTIVE="${CHEZMOI_NONINTERACTIVE:-${NONINTERACTIVE:-}}"
OS_NAME="$(uname -s)"
BREW_BIN=""

usage() {
  cat <<'EOF'
Usage:
  curl -fsSL https://berrybolt.bot/install.sh | bash

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

log_info() {
  printf "\033[0;34m→ %s\033[0m\n" "$*"
}

log_success() {
  printf "\033[0;32m✓ %s\033[0m\n" "$*"
}

log_error() {
  printf "\033[0;31m✗ %s\033[0m\n" "$*" >&2
  exit 1
}

log_header() {
  echo ""
  printf "=====================================\n"
  printf " BERRY BOLT DOTFILES\n"
  printf " guided setup console\n"
  printf "=====================================\n"
  echo ""
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

find_brew() {
  BREW_BIN=""
  if command -v brew >/dev/null 2>&1; then
    BREW_BIN="$(command -v brew)"
  elif [ -x /opt/homebrew/bin/brew ]; then
    BREW_BIN="/opt/homebrew/bin/brew"
  elif [ -x /usr/local/bin/brew ]; then
    BREW_BIN="/usr/local/bin/brew"
  fi

  [ -n "$BREW_BIN" ]
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
Tip: curl -fsSL $SCRIPT_URL | bash"
  fi
}

is_blank() {
  case ${1-} in
    *[![:space:]]*) return 1 ;;
    *) return 0 ;;
  esac
}

trim_space() {
  printf "%s" "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
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

ensure_homebrew() {
  if [ "$OS_NAME" != "Darwin" ]; then
    return
  fi

  if find_brew; then
    eval "$("$BREW_BIN" shellenv)"
    return
  fi

  if [ -n "$NONINTERACTIVE" ]; then
    log_info "Installing Homebrew in non-interactive mode..."
    if ! NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
      log_error "Homebrew install failed. On shared Macs, install Homebrew once with an Administrator account, then re-run."
    fi
  else
    require_tty
    log_info "Installing Homebrew..."
    if ! /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" < "$TTY_DEV"; then
      log_error "Homebrew install failed. On shared Macs, install Homebrew once with an Administrator account, then re-run."
    fi
  fi

  if ! find_brew; then
    log_error "Homebrew install completed but brew was not found on PATH or in the default install locations."
  fi

  eval "$("$BREW_BIN" shellenv)"
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
    if [ -n "$current" ]; then
      printf "\033[0;34m→ %s [%s]:\033[0m " "$label" "$current"
    elif [ -n "$placeholder" ]; then
      printf "\033[0;34m→ %s [%s]:\033[0m " "$label" "$placeholder"
    else
      printf "\033[0;34m→ %s:\033[0m " "$label"
    fi
    read -r input < "$TTY_DEV" || abort

    input=$(trim_space "$input")
    if is_blank "$input"; then
      if [ -n "$current" ]; then
        input=$current
      elif [ -n "$placeholder" ]; then
        input=$placeholder
      fi
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
    if [ -n "$current" ]; then
      echo "    Token already set. Leave blank to keep."
    fi

    printf "\033[0;34m→ %s:\033[0m " "$label"
    stty -echo < "$TTY_DEV" 2>/dev/null || true
    read -r input < "$TTY_DEV" || abort
    stty echo < "$TTY_DEV" 2>/dev/null || true
    echo ""

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
  choice=""
  selection=""

  require_tty

  while :; do
    echo ""
    echo "AI CLI to install"
    echo "    claude = Anthropic, codex = OpenAI, none = skip."
    if [ -n "$current" ]; then
      echo "    Current: $current"
      echo "    Select keep current to leave unchanged."
      echo "    0) keep current ($current)"
    fi
    echo "    1) claude (Anthropic)"
    echo "    2) codex (OpenAI)"
    echo "    3) none"
    printf "    Enter choice: "
    read -r selection < "$TTY_DEV" || abort

    if is_blank "$selection" && [ -n "$current" ]; then
      choice="$current"
    else
      case "$selection" in
        0)
          if [ -n "$current" ]; then
            choice="$current"
          else
            choice="invalid"
          fi
          ;;
        1) choice="claude" ;;
        2) choice="codex" ;;
        3) choice="none" ;;
        *) choice="invalid" ;;
      esac
    fi

    case "$choice" in
      claude|codex|none)
        ;;
      "$current")
        if [ -n "$current" ]; then
          :
        else
          log_info "Invalid choice. Try again."
          continue
        fi
        ;;
      *)
        log_info "Invalid choice. Try again."
        continue
        ;;
    esac

    PROMPT_VALUE=$choice
    echo "    ✓ AI CLI to install: $PROMPT_VALUE"
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
      1|"") choice="Confirm" ;;
      2) choice="Edit agent name" ;;
      3) choice="Edit agent email" ;;
      4) choice="Edit GitHub handle" ;;
      5) choice="Edit 1Password vault" ;;
      6) choice="Edit token" ;;
      7) choice="Edit AI CLI" ;;
      *)
        log_info "Invalid choice. Try again."
        continue
        ;;
    esac

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
        prompt_string "Agent email" "hi@example.bot" "$AGENT_EMAIL"
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
OP_SERVICE_ACCOUNT_TOKEN=$(trim_space "$OP_SERVICE_ACCOUNT_TOKEN")
case "$OP_SERVICE_ACCOUNT_TOKEN" in
  ops_*) ;;
  "")
    OP_SERVICE_ACCOUNT_TOKEN=""
    ;;
  *)
    log_info "1Password token looks invalid. You will be prompted."
    OP_SERVICE_ACCOUNT_TOKEN=""
    ;;
esac

CHEZMOI_AI_CLI="$(normalize_ai_cli "${CHEZMOI_AI_CLI:-}")"

detect_tty
if [ -n "${CHEZMOI_DEBUG:-}" ]; then
  if [ -n "$OP_SERVICE_ACCOUNT_TOKEN" ]; then
    tail=$(mask_token "$OP_SERVICE_ACCOUNT_TOKEN")
    log_info "debug: tty_dev=${TTY_DEV:-none} noninteractive=${NONINTERACTIVE:-0} token=$tail ai_cli=${CHEZMOI_AI_CLI:-none}"
  else
    log_info "debug: tty_dev=${TTY_DEV:-none} noninteractive=${NONINTERACTIVE:-0} token=missing ai_cli=${CHEZMOI_AI_CLI:-none}"
  fi
fi

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
Tip: curl -fsSL $SCRIPT_URL | bash"
  fi
else
  if is_blank "$AGENT_NAME"; then
    prompt_string "Agent name" "Berry Bolt" "$AGENT_NAME"
    AGENT_NAME=$PROMPT_VALUE
  fi
  if is_blank "$AGENT_EMAIL"; then
    prompt_string "Agent email" "hi@example.bot" "$AGENT_EMAIL"
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
    tail=$(mask_token "$OP_SERVICE_ACCOUNT_TOKEN")
    log_info "1Password token detected ($tail). You can edit in review."
  fi
  if is_blank "$CHEZMOI_AI_CLI"; then
    prompt_ai_cli "$CHEZMOI_AI_CLI"
    CHEZMOI_AI_CLI=$PROMPT_VALUE
  fi

  review_and_edit
fi

#
# 3. Install Homebrew on macOS if needed
#
ensure_homebrew

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
