#!/bin/bash
# shellcheck disable=SC2088  # check descriptions name target paths literally
# Focused regression checks that need no real credentials or target machine.
#
# Every case runs under a throwaway HOME with a clean environment (env -i)
# and a fake `op` that serves generated fixture keys. The real HOME, the
# operator's 1Password session, and GitHub are never touched.
#
# Usage: tests/regression.sh [source-dir]   (default: this checkout)
# Requires: bash, git, ssh-keygen, chezmoi, awk.

set -euo pipefail

SRC="$(cd "${1:-$(dirname "${BASH_SOURCE[0]}")/..}" && pwd)"
TMP_ROOT="${TMPDIR:-/tmp}"
WORK="$(mktemp -d "${TMP_ROOT%/}/dotfiles-regression.XXXXXX")"
# KEEP_WORK=1 keeps the fixtures and $WORK/log for debugging.
if [ -n "${KEEP_WORK:-}" ]; then
  echo "Keeping $WORK"
else
  trap 'rm -rf "$WORK"' EXIT
fi

CHEZMOI_BIN="$(command -v chezmoi)" || { echo "chezmoi is required on PATH" >&2; exit 1; }
BASE_PATH="$WORK/fakebin:$(dirname "$CHEZMOI_BIN"):/usr/bin:/bin:/usr/sbin:/sbin"

pass=0
fail=0

check() {
  local desc=$1
  shift
  if "$@" >>"$WORK/log" 2>&1; then
    printf '  \033[0;32m✓\033[0m %s\n' "$desc"
    pass=$((pass + 1))
  else
    printf '  \033[0;31m✗\033[0m %s\n' "$desc" >&2
    fail=$((fail + 1))
  fi
}

perm_of() {
  stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"
}

pub_of() {
  ssh-keygen -y -P '' -f "$1" | awk '{print $1, $2}'
}

# --- Fixtures -----------------------------------------------------------------

VAULT="Fixture Vault"
# A non-default item ID proves no consumer still assumes the id_ed25519 title.
ITEM="fixtureitemid0123456789abc"
EMAIL="agent@example.com"

mkdir -p "$WORK/fakebin" "$WORK/op"
cat >"$WORK/fakebin/op" <<'EOF'
#!/bin/bash
# Fake 1Password CLI: serves the fixture key pair in $FAKE_OP_DIR.
set -eu
for arg in "$@"; do
  [ "$arg" = --version ] && { echo 2.32.0; exit 0; }
done
[ "${1:-}" = read ] || { echo "fake op: unsupported: $*" >&2; exit 1; }
[ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ] || { echo "fake op: no token" >&2; exit 1; }
uri=""
for arg in "$@"; do
  case $arg in op://*) uri=$arg ;; esac
done
echo "$uri" >>"$FAKE_OP_DIR/requests"
case $uri in
  "op://$FAKE_OP_VAULT/$FAKE_OP_ITEM/public key") cat "$FAKE_OP_DIR/key.pub" ;;
  "op://$FAKE_OP_VAULT/$FAKE_OP_ITEM/private key?ssh-format=openssh") cat "$FAKE_OP_DIR/key" ;;
  *) echo "[ERROR] fake op: item not found: $uri" >&2; exit 1 ;;
esac
EOF
chmod 755 "$WORK/fakebin/op"

ssh-keygen -q -t ed25519 -N '' -C fixture-a -f "$WORK/key-a"
ssh-keygen -q -t ed25519 -N '' -C fixture-b -f "$WORK/key-b"
ssh-keygen -q -t ed25519 -N '' -C fixture-c -f "$WORK/key-c"

# Serve fixture key pair a|b from the fake 1Password item.
serve_key() {
  cp "$WORK/key-$1" "$WORK/op/key"
  cp "$WORK/key-$1.pub" "$WORK/op/key.pub"
}

OMARCHY_BASHRC='# Omarchy environment (OMARCHY_PATH + PATH), needed even for non-interactive shells
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap

# If not running interactively, don'"'"'t do anything else (leave this above the rc source)
[[ $- != *i* ]] && return

source "$OMARCHY_PATH/default/bash/rc"

# Add your own exports, aliases, and functions here.
alias p='"'"'python'"'"'
'
USER_MISE='[tools]
node = "lts"
'
USER_SSH_CONFIG='ServerAliveInterval 17

Host example.org
  Port 2222
'

# Build a fake Omarchy home with the candidate source checked out at the
# default location behind a GitHub HTTPS origin, as a fresh clone leaves it.
new_home() {
  local h
  h=$(mktemp -d "$WORK/home.XXXXXX")
  chmod 700 "$h"
  mkdir -p "$h/.config/mise" "$h/.local/share"
  chmod 755 "$h/.config"
  printf '%s' "$OMARCHY_BASHRC" >"$h/.bashrc"
  printf '%s' "$USER_MISE" >"$h/.config/mise/config.toml"
  mkdir -m 755 "$h/.ssh"
  printf '%s' "$USER_SSH_CONFIG" >"$h/.ssh/config"
  mkdir "$h/.local/share/chezmoi"
  (cd "$SRC" && tar cf - --exclude .git --exclude .local --exclude PLAN.md --exclude .env --exclude tests/.env.local .) |
    (cd "$h/.local/share/chezmoi" && tar xf -)
  git -C "$h/.local/share/chezmoi" init -q
  git -C "$h/.local/share/chezmoi" add -A
  git -C "$h/.local/share/chezmoi" -c user.name=t -c user.email=t@example.com -c commit.gpgsign=false commit -qm fixture
  git -C "$h/.local/share/chezmoi" remote add origin https://github.com/example/dotfiles.git
  printf '%s' "$h"
}

# Run a command inside fixture home $1 with a clean environment.
in_home() {
  local h=$1
  shift
  env -i HOME="$h" PATH="$BASE_PATH" TERM=dumb LANG=C \
    FAKE_OP_DIR="$WORK/op" FAKE_OP_VAULT="$VAULT" FAKE_OP_ITEM="$ITEM" "$@"
}

INIT_ENV="CHEZMOI_AGENT_NAME=Fixture Agent"
init_apply() {
  local h=$1
  in_home "$h" env "$INIT_ENV" CHEZMOI_AGENT_EMAIL="$EMAIL" CHEZMOI_AGENT_HANDLE_GITHUB=example \
    CHEZMOI_OP_VAULT="$VAULT" CHEZMOI_OP_SSH_ITEM="$ITEM" OP_SERVICE_ACCOUNT_TOKEN=ops_fixture_one \
    chezmoi init --apply --no-tty --exclude=scripts </dev/null
}

render_script() {
  local h=$1 name=$2
  in_home "$h" chezmoi execute-template --no-tty \
    <"$SRC/home/.chezmoiscripts/$name" >"$h/$name.sh"
}

# --- Installer ----------------------------------------------------------------

echo "Installer"

installer_tools_match_manifest() {
  local installer manifest script
  installer=$(bash -c '. "$1"; printf "%s\n" "${BOOTSTRAP_TOOLS[@]%@*}"' _ "$SRC/install.sh" | sort)
  manifest=$(awk '/^\[tools\]/{t=1;next} /^\[/{t=0} t && /=/{print $1}' \
    "$SRC/home/dot_config/mise/conf.d/dotfiles.toml" | sort)
  script=$(sed -n 's/^mise install --yes //p' \
    "$SRC/home/.chezmoiscripts/run_once_after_10-install-mise-tools.sh.tmpl" | tr ' ' '\n' | sort)
  [ -n "$manifest" ] && [ "$installer" = "$manifest" ] && [ "$script" = "$manifest" ]
}
check "installer and apply script install exactly the mise manifest tools" installer_tools_match_manifest

noninteractive_requires_inputs() {
  local out
  if out=$(env -i HOME="$WORK" PATH="$BASE_PATH" CHEZMOI_NONINTERACTIVE=1 \
    bash -c '. "$1"; collect_inputs' _ "$SRC/install.sh" 2>&1); then
    return 1
  fi
  case $out in
    *"CHEZMOI_AGENT_NAME CHEZMOI_AGENT_EMAIL CHEZMOI_AGENT_HANDLE_GITHUB CHEZMOI_OP_VAULT CHEZMOI_OP_SSH_ITEM OP_SERVICE_ACCOUNT_TOKEN"*) ;;
    *) return 1 ;;
  esac
}
check "non-interactive install names every missing input" noninteractive_requires_inputs

preflight_matches_host() {
  local id="" out rc
  [ -r /etc/os-release ] && id=$(. /etc/os-release && printf '%s' "${ID:-}")
  mkdir -p "$WORK/preflight-home"
  touch "$WORK/preflight-home/.bashrc"
  out=$(env -i HOME="$WORK/preflight-home" PATH="$BASE_PATH" \
    bash -c '. "$1"; preflight' _ "$SRC/install.sh" 2>&1) && rc=0 || rc=$?
  if [ "$id" = omarchy ]; then
    [ "$rc" -eq 0 ]
  else
    [ "$rc" -ne 0 ] && case $out in *"Omarchy only"*) true ;; *) false ;; esac
  fi
}
check "preflight rejects hosts other than Omarchy" preflight_matches_host

# --- Revision selection ---------------------------------------------------------

echo "Revision selection"

REV_REMOTE="$WORK/rev-remote.git"
git init -q --bare "$REV_REMOTE"
git clone -q "$REV_REMOTE" "$WORK/rev-seed" 2>/dev/null
for n in 1 2; do
  echo "$n" >"$WORK/rev-seed/file"
  git -C "$WORK/rev-seed" add file
  git -C "$WORK/rev-seed" -c user.name=t -c user.email=t@example.com -c commit.gpgsign=false commit -qm "c$n"
done
git -C "$WORK/rev-seed" push -q origin HEAD:refs/heads/main
REV_OLD=$(git -C "$WORK/rev-seed" rev-parse HEAD~1)
REV_HOME=$(mktemp -d "$WORK/rev-home.XXXXXX")
REV_SRC="$REV_HOME/.local/share/chezmoi"

# Run install.sh's argument parsing and source sync in REV_HOME; the
# output lands in $WORK/rev-out for message checks.
rev_sync() {
  env -i HOME="$REV_HOME" PATH="$BASE_PATH" \
    bash -c '. "$1"; repo=$2; shift 2; parse_cli_args "$@"; validate_revision; sync_source "$repo"' \
    _ "$SRC/install.sh" "$REV_REMOTE" "$@" >"$WORK/rev-out" 2>&1
}
rev_out_has() {
  grep -qF -- "$1" "$WORK/rev-out"
}
rev_head_is() {
  [ "$(git -C "$REV_SRC" rev-parse HEAD)" = "$1" ]
}

short_sha_rejected() {
  ! rev_sync --revision "$(printf '%.12s' "$REV_OLD")" && rev_out_has "full 40-character"
}
check "--revision rejects a short SHA" short_sha_rejected

check "fresh install checks out the pinned non-tip revision" \
  eval 'rev_sync --revision "$REV_OLD" && rev_head_is "$REV_OLD"'

# Publish a commit the existing checkout has never seen.
echo 3 >"$WORK/rev-seed/file"
git -C "$WORK/rev-seed" -c user.name=t -c user.email=t@example.com -c commit.gpgsign=false commit -qam c3
git -C "$WORK/rev-seed" push -q origin HEAD:refs/heads/main
REV_TIP=$(git -C "$WORK/rev-seed" rev-parse HEAD)
check "repeat install fetches and checks out a new pinned revision" \
  eval 'rev_sync "--revision=$REV_TIP" && rev_out_has "Fetching revision" && rev_head_is "$REV_TIP"'

detached_without_revision_fails() {
  ! rev_sync && rev_out_has "detached" && rev_head_is "$REV_TIP"
}
check "repeat install without --revision refuses a detached source" detached_without_revision_fails

unknown_revision_fails() {
  ! rev_sync --revision 0000000000000000000000000000000000000001 &&
    rev_out_has "Cannot fetch revision" && rev_head_is "$REV_TIP"
}
check "an unavailable revision fails clearly and leaves HEAD alone" unknown_revision_fails

dirty_source_refused() {
  echo local >>"$REV_SRC/file"
  ! rev_sync --revision "$REV_OLD" && rev_out_has "local modifications" && rev_head_is "$REV_TIP"
}
check "a source with local modifications is refused" dirty_source_refused
git -C "$REV_SRC" checkout -q -- file

unknown_argument_fails() {
  ! rev_sync --bogus && rev_out_has "Unknown argument: --bogus"
}
check "unknown installer arguments fail" unknown_argument_fails

# --- Unattended init ------------------------------------------------------------

echo "Unattended init"

H=$(new_home)
serve_key a

config_renders_without_prompt() {
  local out
  out=$(in_home "$H" env "$INIT_ENV" CHEZMOI_AGENT_EMAIL="$EMAIL" CHEZMOI_AGENT_HANDLE_GITHUB=example \
    CHEZMOI_OP_VAULT="$VAULT" CHEZMOI_OP_SSH_ITEM="$ITEM" OP_SERVICE_ACCOUNT_TOKEN=ops_fixture_one \
    chezmoi execute-template --init --no-tty --stdinisatty=false \
    --file "$SRC/home/.chezmoi.toml.tmpl" </dev/null 2>&1) || return 1
  case $out in *"op_vault = \"$VAULT\""*) ;; *) return 1 ;; esac
  case $out in *"op_ssh_item = \"$ITEM\""*) ;; *) return 1 ;; esac
  case $out in *ai_cli* | *agent_workspace_repo* | *ops_fixture*) return 1 ;; esac
}
check "config template renders from env inputs with no prompt or token" config_renders_without_prompt

config_requires_token() {
  ! in_home "$H" env "$INIT_ENV" CHEZMOI_AGENT_EMAIL="$EMAIL" CHEZMOI_AGENT_HANDLE_GITHUB=example \
    CHEZMOI_OP_VAULT="$VAULT" CHEZMOI_OP_SSH_ITEM="$ITEM" chezmoi execute-template --init --no-tty --stdinisatty=false \
    --file "$SRC/home/.chezmoi.toml.tmpl" </dev/null
}
check "config template fails without OP_SERVICE_ACCOUNT_TOKEN" config_requires_token

check "fresh chezmoi init --apply succeeds unattended" init_apply "$H"

# --- Applied files ----------------------------------------------------------------

echo "Applied files"

bashrc_preserved() {
  local b="$H/.bashrc"
  head -c "${#OMARCHY_BASHRC}" "$b" | cmp -s - <(printf '%s' "$OMARCHY_BASHRC") &&
    [ "$(grep -c '^# >>> dotfiles >>>$' "$b")" -eq 1 ] &&
    grep -qxF 'op() { with-op op "$@"; }' "$b"
}
check "~/.bashrc keeps Omarchy content and gains one dotfiles block" bashrc_preserved

check "user mise config.toml is untouched" \
  cmp -s "$H/.config/mise/config.toml" <(printf '%s' "$USER_MISE")
check "dotfiles mise manifest lands in conf.d" test -f "$H/.config/mise/conf.d/dotfiles.toml"
check "~/.config keeps its mode (755)" test "$(perm_of "$H/.config")" = 755
check "~/.config/op is 700" test "$(perm_of "$H/.config/op")" = 700
check "~/.config/op/env is 600" test "$(perm_of "$H/.config/op/env")" = 600
check "~/.config/op/env holds the supplied token" grep -qxF 'OP_SERVICE_ACCOUNT_TOKEN="ops_fixture_one"' "$H/.config/op/env"
check "chezmoi config does not persist the token" bash -c '! grep -q ops_ "$1"' _ "$H/.config/chezmoi/chezmoi.toml"
check "allowed_signers trusts the 1Password public key" \
  grep -qxF "$EMAIL $(awk '{print $1, $2}' "$WORK/key-a.pub")" <(awk '{print $1, $2, $3}' "$H/.config/git/allowed_signers")
check "gitconfig signs with the restored key" grep -qF "signingkey = $H/.ssh/id_ed25519" "$H/.gitconfig"
check "gitconfig has no gh credential helper" bash -c '! grep -q "gh auth" "$1"' _ "$H/.gitconfig"
ssh_config_routes_github() {
  local c="$H/.ssh/config" g
  g=$(ssh -F "$c" -G github.com 2>/dev/null)
  printf '%s\n' "$g" | grep -qx 'hostname ssh.github.com' &&
    printf '%s\n' "$g" | grep -qx 'port 443' &&
    printf '%s\n' "$g" | grep -qx 'hostkeyalias github.com' &&
    ssh -F "$c" -G example.org 2>/dev/null | grep -qx 'port 2222' &&
    ssh -F "$c" -G other.example 2>/dev/null | grep -qx 'serveraliveinterval 17'
}
check "~/.ssh/config routes GitHub through ssh.github.com:443" ssh_config_routes_github
check "~/.ssh/config keeps the user's entries after the block" \
  cmp -s <(tail -c "${#USER_SSH_CONFIG}" "$H/.ssh/config") <(printf '%s' "$USER_SSH_CONFIG")
check "~/.ssh is 700 and ~/.ssh/config is 600" \
  test "$(perm_of "$H/.ssh")/$(perm_of "$H/.ssh/config")" = 700/600
check "with-op and chezmoi-with-op are executable" \
  test -x "$H/.local/bin/with-op" -a -x "$H/.local/bin/chezmoi-with-op"

reapply_is_clean() {
  in_home "$H" env OP_SERVICE_ACCOUNT_TOKEN=ops_fixture_one chezmoi verify --no-tty --exclude=scripts </dev/null &&
    in_home "$H" env OP_SERVICE_ACCOUNT_TOKEN=ops_fixture_one chezmoi apply --no-tty --exclude=scripts </dev/null &&
    in_home "$H" env OP_SERVICE_ACCOUNT_TOKEN=ops_fixture_one chezmoi verify --no-tty --exclude=scripts </dev/null &&
    [ "$(grep -c '^# >>> dotfiles >>>$' "$H/.bashrc")" -eq 1 ] &&
    [ "$(grep -c '^# >>> dotfiles >>>$' "$H/.ssh/config")" -eq 1 ]
}
check "reapply leaves no managed-file drift" reapply_is_clean

# --- Bash integration -----------------------------------------------------------

echo "Bash integration"

op_function_scopes_token() {
  local out shims="$H/.local/share/mise/shims"
  # Stand in for the mise op shim that with-op resolves first.
  mkdir -p "$shims"
  printf '#!/bin/bash\necho "child=${OP_SERVICE_ACCOUNT_TOKEN:-} vault=${OP_VAULT:-}"\n' >"$shims/op"
  chmod 755 "$shims/op"
  # Source only the dotfiles block; Omarchy files are absent on this host.
  out=$(in_home "$H" bash -c '
    eval "$(sed -n "/^# >>> dotfiles >>>$/,/^# <<< dotfiles <<<$/p" "$HOME/.bashrc")"
    PATH="$HOME/.local/bin:$PATH"
    op
    echo "parent=${OP_SERVICE_ACCOUNT_TOKEN:-}"
  ')
  rm -f "$shims/op"
  [ "$out" = "child=ops_fixture_one vault=$VAULT
parent=" ]
}
check "op() loads the token only into the wrapped command" op_function_scopes_token

# chezmoi-with-op token precedence, exercised with real chezmoi applies.
CWO="$H/.local/bin/chezmoi-with-op"
# cwo_apply <token or ""> [apply args...]
cwo_apply() {
  local token=$1
  shift
  in_home "$H" ${token:+env OP_SERVICE_ACCOUNT_TOKEN="$token"} "$CWO" apply --no-tty --exclude=scripts "$@" </dev/null
}
env_token_is() {
  grep -qxF "OP_SERVICE_ACCOUNT_TOKEN=\"$1\"" "$H/.config/op/env"
}

missing_env_restored_with_supplied_token() {
  rm "$H/.config/op/env"
  cwo_apply ops_fixture_two --force "$H/.config/op/env" && env_token_is ops_fixture_two &&
    [ "$(perm_of "$H/.config/op/env")" = 600 ]
}
check "chezmoi-with-op restores a missing env file from a supplied token" missing_env_restored_with_supplied_token

supplied_token_wins_over_file() {
  cwo_apply ops_fixture_three && env_token_is ops_fixture_three
}
check "a supplied token re-renders the env file instead of reusing the old one" supplied_token_wins_over_file

check "without a supplied token the env file's token is kept" \
  eval 'cwo_apply "" && env_token_is ops_fixture_three'

missing_env_and_token_fails() {
  local out
  mv "$H/.config/op/env" "$WORK/env.saved"
  out=$(cwo_apply "" 2>&1) && rc=0 || rc=$?
  mv "$WORK/env.saved" "$H/.config/op/env"
  [ "$rc" -ne 0 ] && case $out in *"not found and OP_SERVICE_ACCOUNT_TOKEN was not supplied"*) true ;; *) false ;; esac
}
check "chezmoi-with-op fails clearly with neither env file nor token" missing_env_and_token_fails

# Later cases expect the original fixture token.
cwo_apply ops_fixture_one >/dev/null 2>&1

with_op_requires_env_file() {
  local h out
  h=$(new_home)
  mkdir -p "$h/.local/bin"
  cp "$SRC/home/dot_local/bin/executable_with-op" "$h/.local/bin/with-op"
  chmod 755 "$h/.local/bin/with-op"
  ! out=$(in_home "$h" "$h/.local/bin/with-op" true 2>&1) &&
    case $out in *"config/op/env not found"*) true ;; *) false ;; esac
}
check "with-op fails clearly without ~/.config/op/env" with_op_requires_env_file

# --- SSH restoration ----------------------------------------------------------------

echo "SSH restoration"

render_script "$H" run_after_30-restore-ssh-key.sh.tmpl
S30="$H/run_after_30-restore-ssh-key.sh.tmpl.sh"
run_s30() {
  in_home "$H" env OP_SERVICE_ACCOUNT_TOKEN=ops_fixture_one bash "$S30"
}

check "restore script renders and parses" bash -n "$S30"

# Seed an unrelated host and a stale github.com entry (fixture keys).
{
  printf 'example.org %s\n' "$(awk '{print $1, $2}' "$WORK/key-a.pub")"
  printf 'github.com %s\n' "$(awk '{print $1, $2}' "$WORK/key-b.pub")"
} >"$H/.ssh/known_hosts"
STALE_GITHUB_KEY=$(awk '{print $2}' "$WORK/key-b.pub")

missing_key_restored() {
  run_s30 &&
    [ "$(pub_of "$H/.ssh/id_ed25519")" = "$(awk '{print $1, $2}' "$WORK/key-a.pub")" ] &&
    [ "$(perm_of "$H/.ssh/id_ed25519")" = 600 ] &&
    [ "$(perm_of "$H/.ssh")" = 700 ] &&
    [ -f "$H/.ssh/id_ed25519.pub" ]
}
check "missing SSH key is restored from 1Password" missing_key_restored

known_hosts_pinned() {
  local kh="$H/.ssh/known_hosts"
  grep -q '^example.org ' "$kh" &&
    ! grep -qF "$STALE_GITHUB_KEY" "$kh" &&
    [ "$(grep -c '^github.com ' "$kh")" -eq 3 ] &&
    cmp -s <(grep '^github.com ' "$kh") <(grep '^github.com ' "$SRC/home/dot_local/share/ssh-bootstrap/github_known_hosts")
}
check "known_hosts pins GitHub keys and keeps other hosts" known_hosts_pinned

check "source remote switches from HTTPS to SSH" \
  test "$(git -C "$H/.local/share/chezmoi" remote get-url origin)" = git@github.com:example/dotfiles.git

matching_key_kept() {
  local before
  before=$(cat "$H/.ssh/id_ed25519")
  run_s30 && [ "$(cat "$H/.ssh/id_ed25519")" = "$before" ] &&
    ! compgen -G "$H/.ssh/id_ed25519*.stale.*" >/dev/null
}
check "matching key is left in place on reapply" matching_key_kept

rotated_key_adopted() {
  serve_key b
  run_s30 &&
    [ "$(pub_of "$H/.ssh/id_ed25519")" = "$(awk '{print $1, $2}' "$WORK/key-b.pub")" ] &&
    stale=$(compgen -G "$H/.ssh/id_ed25519.stale.*" | head -1) &&
    [ "$(pub_of "$stale")" = "$(awk '{print $1, $2}' "$WORK/key-a.pub")" ]
}
check "rotated key replaces the old key and keeps it as .stale" rotated_key_adopted

mismatched_item_leaves_key() {
  local before stale_before
  before=$(cat "$H/.ssh/id_ed25519")
  stale_before=$(compgen -G "$H/.ssh/id_ed25519.stale.*" | wc -l)
  # The item's public key says A, but its private key is C.
  cp "$WORK/key-c" "$WORK/op/key"
  cp "$WORK/key-a.pub" "$WORK/op/key.pub"
  ! run_s30 &&
    [ "$(cat "$H/.ssh/id_ed25519")" = "$before" ] &&
    [ "$(compgen -G "$H/.ssh/id_ed25519.stale.*" | wc -l)" -eq "$stale_before" ] &&
    [ ! -e "$H/.ssh/id_ed25519.tmp" ]
}
check "a mismatched 1Password key pair fails and keeps the current key" mismatched_item_leaves_key
serve_key b

missing_pub_rewritten() {
  rm -f "$H/.ssh/id_ed25519.pub"
  run_s30 && [ "$(awk '{print $1, $2}' "$H/.ssh/id_ed25519.pub")" = "$(awk '{print $1, $2}' "$WORK/key-b.pub")" ]
}
check "a missing id_ed25519.pub is rewritten on reapply" missing_pub_rewritten

no_leftovers() {
  run_s30 &&
    [ "$(grep -c '^github.com ' "$H/.ssh/known_hosts")" -eq 3 ] &&
    ! grep -q '^#' "$H/.ssh/known_hosts" &&
    ! compgen -G "$H/.ssh/*.tmp*" >/dev/null &&
    ! compgen -G "$H/.ssh/known_hosts.old" >/dev/null
}
check "repeated restores leave no temp files or duplicate known_hosts lines" no_leftovers

only_selected_item_read() {
  # Both consumers (allowed_signers and script 30) read the selected item.
  grep -q "^op://$VAULT/$ITEM/public key$" "$WORK/op/requests" &&
    grep -q "^op://$VAULT/$ITEM/private key" "$WORK/op/requests" &&
    ! grep -v "^op://$VAULT/$ITEM/" "$WORK/op/requests"
}
check "1Password reads use only the configured SSH item" only_selected_item_read

restore_requires_token() {
  local out
  ! out=$(in_home "$H" bash "$S30" 2>&1) &&
    case $out in *OP_SERVICE_ACCOUNT_TOKEN*) true ;; *) false ;; esac
}
mv "$H/.config/op/env" "$WORK/env.saved"
check "restore fails clearly without a token or env file" restore_requires_token
mv "$WORK/env.saved" "$H/.config/op/env"

echo ""
printf '%d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -ne 0 ]; then
  echo "Details: rerun with KEEP_WORK=1 and read \$WORK/log." >&2
  exit 1
fi
