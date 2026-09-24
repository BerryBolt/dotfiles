#!/bin/bash
# shellcheck disable=SC2088  # check descriptions name target paths literally
# Recovery acceptance for an installed Omarchy account.
#
# DESTRUCTIVE to managed state, which it then restores: deletes
# ~/.ssh/id_ed25519, ~/.config/op/env, and the passwordless sudo rule, and
# swaps in a generated fixture key. Run only on a disposable or test account.
# The live 1Password items and GitHub registration are never changed; the
# rotation case simulates a machine that still holds a previous key (a
# test-owned fixture).
#
# The service-account token for the env-file restore is read from stdin
# (one line) so it never appears in arguments or logs:
#   printf '%s\n' "$token" | CHEZMOI_AGENT_EMAIL=... tests/recovery.sh
#
# Inputs (non-secret):
#   CHEZMOI_AGENT_EMAIL  expected allowed_signers identity (required)

set -euo pipefail

: "${CHEZMOI_AGENT_EMAIL:?set CHEZMOI_AGENT_EMAIL}"

SUPPLIED_TOKEN=""
IFS= read -r SUPPLIED_TOKEN || true
if [ -z "$SUPPLIED_TOKEN" ]; then
  echo "recovery.sh: supply the service-account token on stdin" >&2
  exit 2
fi

export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:/usr/local/bin:/usr/bin:/bin:$PATH"
unset OP_SERVICE_ACCOUNT_TOKEN OP_VAULT OP_FORMAT

KEY="$HOME/.ssh/id_ed25519"
ENV_FILE="$HOME/.config/op/env"
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

pub_of() {
  ssh-keygen -y -P '' -f "$1" | awk '{print $1, $2}'
}

signers_pub() {
  awk -v e="$CHEZMOI_AGENT_EMAIL" '$1 == e {print $2, $3}' "$HOME/.config/git/allowed_signers"
}

key_matches_signers() {
  [ "$(stat -c '%a' "$KEY")" = 600 ] && [ "$(pub_of "$KEY")" = "$(signers_pub)" ]
}

signed_commit_verifies() {
  local repo="$WORK/sign-$RANDOM"
  git init -q "$repo" &&
    git -C "$repo" commit -q --allow-empty -m "recovery signing test" &&
    git -C "$repo" verify-commit HEAD
}

reapply() {
  chezmoi-with-op apply --no-tty </dev/null
}

echo "Missing SSH key"
rm -f "$KEY" "$KEY.pub"
check "reapply restores a deleted key" reapply
check "restored key is 0600 and matches allowed_signers" key_matches_signers
check "signing works with the restored key" signed_commit_verifies

echo "Rotated SSH key (fixture previous key)"
ssh-keygen -q -t ed25519 -N '' -C dotfiles-recovery-fixture -f "$WORK/previous"
cp "$WORK/previous" "$KEY"
cp "$WORK/previous.pub" "$KEY.pub"
chmod 600 "$KEY"
before=$(compgen -G "$KEY.stale.*" | sort || true)
check "reapply adopts the 1Password key over the previous one" reapply
check "adopted key matches allowed_signers" key_matches_signers
new_stale=$(comm -13 <(printf '%s\n' "$before") <(compgen -G "$KEY.stale.*" | sort || true) | grep -v '^$' || true)
check "previous key is kept as .stale" \
  test -n "$new_stale" -a "$(pub_of "${new_stale:-/nonexistent}" 2>/dev/null)" = "$(awk '{print $1, $2}' "$WORK/previous.pub")"
check "signing works after adoption" signed_commit_verifies
# The stale copies are this test's fixture material; remove them.
if [ -n "$new_stale" ]; then
  rm -f "$new_stale" "${new_stale/id_ed25519.stale./id_ed25519.pub.stale.}"
fi

echo "Missing passwordless sudo rule"
SUDOERS_FILE=/etc/sudoers.d/05-dotfiles-nopasswd
sudo -n rm -f "$SUDOERS_FILE"
check "sudo asks for a password without the rule" bash -c '! sudo -k -n true 2>/dev/null'
check "reapply restores the rule with the account password from 1Password" reapply
check "sudo runs without a password again" sudo -k -n true

echo "Missing credential env file"
rm -f "$ENV_FILE"
no_token_fails_clearly() {
  ! chezmoi-with-op apply --no-tty </dev/null 2>"$WORK/err" &&
    grep -q 'OP_SERVICE_ACCOUNT_TOKEN was not supplied' "$WORK/err" &&
    ! with-op true 2>"$WORK/err2" && grep -q 'not found' "$WORK/err2"
}
check "wrappers fail clearly with neither env file nor token" no_token_fails_clearly
restore_env() {
  OP_SERVICE_ACCOUNT_TOKEN="$SUPPLIED_TOKEN" chezmoi-with-op apply --no-tty --force "$ENV_FILE" </dev/null
}
check "a supplied token restores ~/.config/op/env" restore_env
check "restored env file is 0600 in a 0700 directory" \
  test "$(stat -c '%a' "$HOME/.config/op")/$(stat -c '%a' "$ENV_FILE")" = 700/600
check "op works again through with-op" \
  bash -c 'with-op op whoami | grep -q "\"SERVICE_ACCOUNT\""'

echo "Final state"
check "reapply succeeds without a supplied token" reapply
check "no managed-file drift" chezmoi-with-op verify --exclude=scripts
check "no leftover key temp files" bash -c '! compgen -G "$HOME/.ssh/*.tmp*" >/dev/null'

echo ""
printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
