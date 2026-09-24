#!/usr/bin/env bash
# Bootstrap the Omarchy workstation fundamentals for an agent account.
# Usage:
#   curl -fsSL https://berrybolt.bot/install.sh | bash

set -euo pipefail

SCRIPT_URL="https://berrybolt.bot/install.sh"
NONINTERACTIVE="${CHEZMOI_NONINTERACTIVE:-${NONINTERACTIVE:-}}"
REVISION="${DOTFILES_REVISION:-}"
SOURCE_DIR="$HOME/.local/share/chezmoi"

# Tools the first apply needs (templates call op). They must also be listed
# in home/dot_config/mise/conf.d/dotfiles.toml, which apply script 10 installs.
BOOTSTRAP_TOOLS=(chezmoi@latest 1password-cli@latest)

# System prerequisites supplied by Omarchy. The installer checks them and
# never installs them.
REQUIRED_COMMANDS=(git ssh ssh-keygen mise)

usage() {
  cat <<'EOF'
Usage:
  curl -fsSL https://berrybolt.bot/install.sh | bash

Env overrides:
  CHEZMOI_AGENT_NAME=...
  CHEZMOI_AGENT_EMAIL=...
  CHEZMOI_AGENT_HANDLE_GITHUB=...
  CHEZMOI_OP_VAULT=...
  CHEZMOI_OP_SSH_ITEM=...   # SSH Key item title or ID in that vault
  OP_SERVICE_ACCOUNT_TOKEN=...

Optional:
  CHEZMOI_NONINTERACTIVE=1  # disable prompts (requires all env vars)
  --non-interactive         # same as above
  --revision <sha>          # apply this full 40-character commit SHA of the
  DOTFILES_REVISION=<sha>   # source instead of the default branch; use the
                            # same SHA as the installer URL when testing

The source repository is https://github.com/<GitHub handle>/dotfiles.git.
EOF
}

parse_cli_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      --non-interactive|--unattended)
        NONINTERACTIVE=1
        ;;
      --revision)
        [ "$#" -ge 2 ] || log_error "--revision requires a full commit SHA"
        REVISION=$2
        shift
        ;;
      --revision=*)
        REVISION=${1#--revision=}
        ;;
      *)
        log_error "Unknown argument: $1 (see --help)"
        ;;
    esac
    shift
  done
}

# Only full SHAs: a branch, tag, or short SHA could resolve differently
# between the installer download and the source fetch.
validate_revision() {
  if [ -n "$REVISION" ] && ! printf '%s' "$REVISION" | grep -Eq '^[0-9a-f]{40}$'; then
    log_error "--revision must be a full 40-character lowercase commit SHA (got: $REVISION)"
  fi
}

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
  printf " Omarchy workstation bootstrap\n"
  printf "=====================================\n"
  echo ""
}

TTY_DEV=""

# A readable /dev/tty node does not imply a controlling terminal; open it.
detect_tty() {
  TTY_DEV=""
  if { : < /dev/tty; } 2>/dev/null; then
    TTY_DEV="/dev/tty"
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

preflight() {
  if [ "$(id -u)" -eq 0 ]; then
    log_error "Run this installer as the target user, not root."
  fi

  os_id=""
  if [ -r /etc/os-release ]; then
    os_id=$(. /etc/os-release && printf '%s' "${ID:-}")
  fi
  if [ "$os_id" != "omarchy" ]; then
    log_error "Unsupported host (os-release ID: ${os_id:-unknown}). This installer supports Omarchy only."
  fi

  missing=""
  for cmd in "${REQUIRED_COMMANDS[@]}"; do
    command -v "$cmd" >/dev/null 2>&1 || missing="$missing $cmd"
  done
  if [ -n "$missing" ]; then
    log_error "Missing required commands:$missing
Omarchy provides these by default. Reinstall the missing packages with pacman and re-run."
  fi

  if [ ! -f "$HOME/.bashrc" ]; then
    # shellcheck disable=SC2088  # name the path as users know it
    log_error "~/.bashrc is missing. Restore Omarchy's default (/etc/skel/.bashrc) and re-run."
  fi
}

PROMPT_VALUE=""

mask_token() {
  printf '%s' "$1" | awk '{ l=length($0); if (l<=4) print $0; else print "..." substr($0,l-3) }'
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

review_and_edit() {
  require_tty
  while :; do
    echo ""
    log_info "Review your choices"
    echo "    Agent name: $AGENT_NAME"
    echo "    Agent email: $AGENT_EMAIL"
    echo "    GitHub handle: $AGENT_HANDLE_GITHUB"
    echo "    1Password vault: $OP_VAULT"
    echo "    1Password SSH key item: $OP_SSH_ITEM"
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
    echo "    6) Edit 1Password SSH key item"
    echo "    7) Edit token"
    printf "    Enter choice [1-7]: "
    read -r selection < "$TTY_DEV" || abort
    case "$selection" in
      1|"")
        if is_blank "$OP_SERVICE_ACCOUNT_TOKEN"; then
          log_info "1Password token required before continuing"
          prompt_secret "1Password service account token" "$OP_SERVICE_ACCOUNT_TOKEN"
          OP_SERVICE_ACCOUNT_TOKEN=$PROMPT_VALUE
          continue
        fi
        break
        ;;
      2)
        prompt_string "Agent name" "Berry Bolt" "$AGENT_NAME"
        AGENT_NAME=$PROMPT_VALUE
        ;;
      3)
        prompt_string "Agent email" "hi@example.bot" "$AGENT_EMAIL"
        AGENT_EMAIL=$PROMPT_VALUE
        ;;
      4)
        prompt_string "GitHub handle" "BerryBolt" "$AGENT_HANDLE_GITHUB"
        AGENT_HANDLE_GITHUB=$PROMPT_VALUE
        ;;
      5)
        prompt_string "1Password vault name" "Berry Bolt" "$OP_VAULT"
        OP_VAULT=$PROMPT_VALUE
        ;;
      6)
        prompt_string "1Password SSH key item (title or ID)" "id_ed25519" "$OP_SSH_ITEM"
        OP_SSH_ITEM=$PROMPT_VALUE
        ;;
      7)
        prompt_secret "1Password service account token" "$OP_SERVICE_ACCOUNT_TOKEN"
        OP_SERVICE_ACCOUNT_TOKEN=$PROMPT_VALUE
        ;;
      *)
        log_info "Invalid choice. Try again."
        ;;
    esac
  done
}

missing_inputs() {
  missing=""
  is_blank "$AGENT_NAME" && missing="$missing CHEZMOI_AGENT_NAME"
  is_blank "$AGENT_EMAIL" && missing="$missing CHEZMOI_AGENT_EMAIL"
  is_blank "$AGENT_HANDLE_GITHUB" && missing="$missing CHEZMOI_AGENT_HANDLE_GITHUB"
  is_blank "$OP_VAULT" && missing="$missing CHEZMOI_OP_VAULT"
  is_blank "$OP_SSH_ITEM" && missing="$missing CHEZMOI_OP_SSH_ITEM"
  is_blank "$OP_SERVICE_ACCOUNT_TOKEN" && missing="$missing OP_SERVICE_ACCOUNT_TOKEN"
  printf '%s' "$missing"
}

collect_inputs() {
  AGENT_NAME="${CHEZMOI_AGENT_NAME:-}"
  AGENT_EMAIL="${CHEZMOI_AGENT_EMAIL:-}"
  AGENT_HANDLE_GITHUB="${CHEZMOI_AGENT_HANDLE_GITHUB:-}"
  OP_VAULT="${CHEZMOI_OP_VAULT:-}"
  OP_SSH_ITEM="${CHEZMOI_OP_SSH_ITEM:-}"
  OP_SERVICE_ACCOUNT_TOKEN=$(trim_space "${OP_SERVICE_ACCOUNT_TOKEN:-}")
  case "$OP_SERVICE_ACCOUNT_TOKEN" in
    ops_*|"") ;;
    *)
      if [ -n "$NONINTERACTIVE" ]; then
        log_error "OP_SERVICE_ACCOUNT_TOKEN does not look like a service account token (expected ops_...)."
      fi
      log_info "1Password token looks invalid. You will be prompted."
      OP_SERVICE_ACCOUNT_TOKEN=""
      ;;
  esac

  detect_tty
  if [ -n "$NONINTERACTIVE" ]; then
    missing=$(missing_inputs)
    if [ -n "$missing" ]; then
      log_error "Non-interactive mode requires env vars:$missing"
    fi
  elif ! has_tty; then
    missing=$(missing_inputs)
    if [ -n "$missing" ]; then
      log_error "No terminal detected.
Set env vars:$missing
Tip: curl -fsSL $SCRIPT_URL | bash"
    fi
  else
    log_info "Answer a few prompts. You can review and edit before apply."
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
    if is_blank "$OP_SSH_ITEM"; then
      prompt_string "1Password SSH key item (title or ID)" "id_ed25519" "$OP_SSH_ITEM"
      OP_SSH_ITEM=$PROMPT_VALUE
    fi
    if is_blank "$OP_SERVICE_ACCOUNT_TOKEN"; then
      echo "    See: https://github.com/${AGENT_HANDLE_GITHUB}/dotfiles/blob/main/skills/1password-setup/SKILL.md"
      echo ""
      prompt_secret "1Password service account token" "$OP_SERVICE_ACCOUNT_TOKEN"
      OP_SERVICE_ACCOUNT_TOKEN=$PROMPT_VALUE
    else
      tail=$(mask_token "$OP_SERVICE_ACCOUNT_TOKEN")
      log_info "1Password token detected ($tail). You can edit in review."
    fi

    review_and_edit
  fi
}

install_bootstrap_tools() {
  log_info "Installing bootstrap tools with mise: ${BOOTSTRAP_TOOLS[*]}"
  if ! mise install --yes "${BOOTSTRAP_TOOLS[@]}"; then
    log_error "mise failed to install: ${BOOTSTRAP_TOOLS[*]}"
  fi
}

with_bootstrap_tools() {
  mise exec "${BOOTSTRAP_TOOLS[@]}" -- "$@"
}

# Check the credential inputs before changing user configuration, so a bad
# token, vault, or key item fails without a partial apply.
verify_credentials() {
  log_info "Verifying 1Password service account access..."
  if ! whoami_json=$(with_bootstrap_tools op whoami --format json 2>/dev/null); then
    log_error "1Password rejected the service account token. Check OP_SERVICE_ACCOUNT_TOKEN."
  fi
  case "$whoami_json" in
    *'"SERVICE_ACCOUNT"'*) ;;
    *) log_error "The 1Password token is not a service account token." ;;
  esac
  if ! with_bootstrap_tools op vault get "$OP_VAULT" >/dev/null 2>&1; then
    log_error "The service account cannot access 1Password vault: $OP_VAULT"
  fi
  if ! with_bootstrap_tools op read "op://$OP_VAULT/$OP_SSH_ITEM/public key" >/dev/null 2>&1; then
    log_error "Cannot read the SSH key item: op://$OP_VAULT/$OP_SSH_ITEM (SSH Key with 'public key' and 'private key'). Check CHEZMOI_OP_SSH_ITEM."
  fi
}

# Detach the source at $REVISION, fetching it from origin when it is not
# already present, and prove HEAD landed there.
checkout_revision() {
  if ! git -C "$SOURCE_DIR" cat-file -e "$REVISION^{commit}" 2>/dev/null; then
    log_info "Fetching revision $REVISION..."
    if ! git -C "$SOURCE_DIR" fetch --quiet origin "$REVISION"; then
      log_error "Cannot fetch revision $REVISION from origin. Push it first and pass the full SHA."
    fi
  fi
  if ! git -C "$SOURCE_DIR" checkout --quiet --detach "$REVISION"; then
    log_error "Cannot check out revision $REVISION."
  fi
  if [ "$(git -C "$SOURCE_DIR" rev-parse HEAD)" != "$REVISION" ]; then
    log_error "Source is not at the requested revision $REVISION."
  fi
}

# Clone the public source on first install. Afterwards, sync over the SSH
# remote that the apply script configured; never fall back to HTTPS.
sync_source() {
  repo=$1

  if [ ! -e "$SOURCE_DIR" ]; then
    log_info "Cloning dotfiles source from $repo..."
    mkdir -p "$(dirname "$SOURCE_DIR")"
    if ! git clone --quiet "$repo" "$SOURCE_DIR"; then
      log_error "Failed to clone dotfiles source: $repo"
    fi
    if [ -n "$REVISION" ]; then
      checkout_revision
    fi
    return
  fi

  if [ ! -d "$SOURCE_DIR/.git" ]; then
    log_error "$SOURCE_DIR exists but is not a git checkout."
  fi

  current_remote="$(git -C "$SOURCE_DIR" remote get-url origin 2>/dev/null || true)"
  case "$current_remote" in
    git@*|ssh://*|/*|file://*)
      ;;
    http://*|https://*)
      log_error "chezmoi source remote must use SSH or a local path. Current origin: $current_remote"
      ;;
    "")
      log_error "chezmoi source remote is blank; fix origin and re-run."
      ;;
    *)
      log_error "Unsupported chezmoi source remote: $current_remote"
      ;;
  esac

  if [ -n "$(git -C "$SOURCE_DIR" status --porcelain)" ]; then
    log_error "$SOURCE_DIR has local modifications. Commit and push or discard them, then re-run."
  fi

  if [ -n "$REVISION" ]; then
    checkout_revision
    return
  fi

  if ! git -C "$SOURCE_DIR" symbolic-ref -q HEAD >/dev/null; then
    log_error "$SOURCE_DIR is detached at $(git -C "$SOURCE_DIR" rev-parse HEAD) from a pinned install. Re-run with --revision <sha>, or check out a branch."
  fi
  log_info "Updating dotfiles source..."
  if ! git -C "$SOURCE_DIR" pull --ff-only --quiet; then
    log_error "git pull failed. SSH source sync must work before bootstrap can continue."
  fi
}

bootstrap_main() {
  repo=${1:-}

  preflight
  validate_revision
  log_header
  collect_inputs

  if is_blank "$repo"; then
    repo="https://github.com/${AGENT_HANDLE_GITHUB}/dotfiles.git"
  fi

  export CHEZMOI_AGENT_NAME="$AGENT_NAME"
  export CHEZMOI_AGENT_EMAIL="$AGENT_EMAIL"
  export CHEZMOI_AGENT_HANDLE_GITHUB="$AGENT_HANDLE_GITHUB"
  export CHEZMOI_OP_VAULT="$OP_VAULT"
  export CHEZMOI_OP_SSH_ITEM="$OP_SSH_ITEM"
  export OP_SERVICE_ACCOUNT_TOKEN

  install_bootstrap_tools
  verify_credentials
  sync_source "$repo"
  log_info "Dotfiles source at $(git -C "$SOURCE_DIR" rev-parse HEAD)"

  log_info "Applying dotfiles..."
  if ! with_bootstrap_tools chezmoi init --apply; then
    log_error "chezmoi apply failed"
  fi

  echo ""
  log_success "Bootstrap complete"
  echo '    Open a new terminal, or run: exec bash -l'
  echo "    Credential commands: op, with-op, chezmoi-with-op (see policies/credentials.md)."
  echo "    Re-run behavior and recovery scope: ARCHITECTURE.md#recovery."
  echo ""
}

parse_cli_args "$@"

bootstrap_main
