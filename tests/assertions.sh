#!/bin/bash
# shellcheck disable=SC2088  # check descriptions name target paths literally
# Fundamentals assertions for an installed Omarchy account.
#
# Run as the target user after install.sh, from a shell that does NOT hold
# the service-account token. Uses live 1Password and GitHub access, creates
# one signed commit in a temporary local repository, and never pushes.
# Prints no credential values.
#
# Inputs (non-secret):
#   CHEZMOI_AGENT_EMAIL          expected Git identity email (required)
#   CHEZMOI_AGENT_HANDLE_GITHUB  expected GitHub SSH greeting (required)
#   EXPECTED_REVISION            full SHA the chezmoi source must be at (optional)

set -euo pipefail

: "${CHEZMOI_AGENT_EMAIL:?set CHEZMOI_AGENT_EMAIL}"
: "${CHEZMOI_AGENT_HANDLE_GITHUB:?set CHEZMOI_AGENT_HANDLE_GITHUB}"

# Initialize PATH before any check: a child install cannot change this
# process's environment, and callers may start with a stripped PATH.
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:/usr/local/bin:/usr/bin:/bin:$PATH"
# Prove the checks do not depend on a token in the calling shell.
unset OP_SERVICE_ACCOUNT_TOKEN OP_VAULT OP_FORMAT

SOURCE_DIR="$HOME/.local/share/chezmoi"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0
fail=0

check() {
  local desc=$1
  shift
  if "$@" >"$WORK/out" 2>&1; then
    printf '  \033[0;32m✓\033[0m %s\n' "$desc"
    pass=$((pass + 1))
  else
    printf '  \033[0;31m✗\033[0m %s\n' "$desc"
    fail=$((fail + 1))
  fi
}

mode_is() {
  [ "$(stat -c '%a' "$1" 2>/dev/null)" = "$2" ]
}

# Run a command in a fresh interactive Bash, as a terminal would.
interactive() {
  bash -ic "$1" </dev/null 2>/dev/null
}

pub_of_key() {
  ssh-keygen -y -P '' -f "$1" | awk '{print $1, $2}'
}

echo "Running fundamentals assertions against $HOME"

echo "Bash integration"
check "~/.bashrc still sources Omarchy's rc" \
  grep -qF 'source "$OMARCHY_PATH/default/bash/rc"' "$HOME/.bashrc"
check "~/.bashrc has exactly one dotfiles block" \
  test "$(grep -c '^# >>> dotfiles >>>$' "$HOME/.bashrc")" -eq 1
check "interactive Bash keeps Omarchy init (functions, mise hook)" \
  interactive '[[ -n $OMARCHY_PATH ]] && declare -F compress >/dev/null && declare -F _mise_hook >/dev/null'
check "interactive Bash defines op as the scoped wrapper" \
  interactive '[[ $(type -t op) == function ]]'
check "interactive Bash resolves with-op, chezmoi-with-op, chezmoi" \
  interactive 'command -v with-op && command -v chezmoi-with-op && command -v chezmoi'
check "interactive Bash does not export the token" \
  interactive '[[ -z ${OP_SERVICE_ACCOUNT_TOKEN:-} ]] && ! env | grep -q "^OP_SERVICE_ACCOUNT_TOKEN="'
check "op whoami reports a service account from a terminal" \
  interactive 'op whoami | grep -q "\"SERVICE_ACCOUNT\""'
check "login shells find chezmoi-with-op, with-op, and chezmoi" \
  env -i HOME="$HOME" PATH=/usr/bin:/bin bash -lc 'command -v chezmoi-with-op && command -v with-op && command -v chezmoi'
check "with-op works for non-interactive callers" \
  env -i HOME="$HOME" PATH=/usr/bin:/bin "$HOME/.local/bin/with-op" bash -c 'op vault get "$OP_VAULT" >/dev/null'

echo "Credentials"
check "~/.config/op is 700" mode_is "$HOME/.config/op" 700
check "~/.config/op/env is 600" mode_is "$HOME/.config/op/env" 600
check "chezmoi config does not persist the token" \
  bash -c '! grep -q "ops_" "$1"' _ "$HOME/.config/chezmoi/chezmoi.toml"

echo "Sudo"
SUDOERS_FILE=/etc/sudoers.d/05-dotfiles-nopasswd
check "sudo runs without a password (rule, not a cached timestamp)" sudo -k -n true
check "sudoers rule is root:root 0440" \
  test "$(sudo -n stat -c '%a %U:%G' "$SUDOERS_FILE")" = "440 root:root"
check "sudoers rule grants this account NOPASSWD: ALL" \
  sudo -n grep -qxF "$(id -un) ALL=(ALL:ALL) NOPASSWD: ALL" "$SUDOERS_FILE"
check "sudoers configuration is valid" sudo -n visudo -c

echo "Tools"
check "chezmoi resolves through mise" chezmoi --version
check "op resolves through mise" op --version
check "dotfiles mise manifest is active" \
  bash -c 'mise config ls | grep -q "conf.d/dotfiles.toml"'

echo "Git identity and signing"
check "git email is the agent email" \
  test "$(git config --global user.email)" = "$CHEZMOI_AGENT_EMAIL"
check "git signs commits with SSH" \
  test "$(git config --global gpg.format)/$(git config --global commit.gpgsign)" = "ssh/true"
check "git signing key is ~/.ssh/id_ed25519" \
  test "$(git config --global user.signingkey)" = "$HOME/.ssh/id_ed25519"

signed_commit_verifies() {
  local repo="$WORK/signing-test"
  git init -q "$repo" &&
    git -C "$repo" commit -q --allow-empty -m "local signing test" &&
    git -C "$repo" verify-commit HEAD &&
    [ "$(git -C "$repo" log -1 --format=%G?)" = G ] &&
    [ -z "$(git -C "$repo" remote)" ]
}
check "a new local commit is signed and verifies (never pushed)" signed_commit_verifies

echo "SSH"
check "~/.ssh is 700" mode_is "$HOME/.ssh" 700
check "~/.ssh/id_ed25519 is 600" mode_is "$HOME/.ssh/id_ed25519" 600
check "allowed_signers matches the on-disk key" \
  test "$(awk '{print $1, $2, $3}' "$HOME/.config/git/allowed_signers")" = \
  "$CHEZMOI_AGENT_EMAIL $(pub_of_key "$HOME/.ssh/id_ed25519")"
check "known_hosts pins exactly the repo's GitHub keys" \
  cmp -s <(grep '^github\.com ' "$HOME/.ssh/known_hosts") \
  <(grep '^github\.com ' "$HOME/.local/share/ssh-bootstrap/github_known_hosts")

github_greets_handle() {
  local out
  out=$(ssh -T -o BatchMode=yes git@github.com 2>&1 || true)
  case $out in *"Hi $CHEZMOI_AGENT_HANDLE_GITHUB!"*) ;; *) return 1 ;; esac
}
check "GitHub SSH authenticates as $CHEZMOI_AGENT_HANDLE_GITHUB" github_greets_handle

echo "Source and drift"
check "chezmoi source has no local modifications" \
  test -z "$(git -C "$SOURCE_DIR" status --porcelain)"
check "chezmoi source remote uses SSH" \
  bash -c 'git -C "$1" remote get-url origin | grep -q "^git@github.com:"' _ "$SOURCE_DIR"
check "chezmoi source syncs over SSH (ls-remote origin)" \
  env GIT_SSH_COMMAND="ssh -o BatchMode=yes" git -C "$SOURCE_DIR" ls-remote --exit-code origin HEAD
if [ -n "${EXPECTED_REVISION:-}" ]; then
  check "chezmoi source is at $EXPECTED_REVISION" \
    test "$(git -C "$SOURCE_DIR" rev-parse HEAD)" = "$EXPECTED_REVISION"
fi
# run_after_ scripts are ensure-state and always pending; check files only.
check "no managed-file drift" chezmoi-with-op verify --exclude=scripts

echo ""
printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
