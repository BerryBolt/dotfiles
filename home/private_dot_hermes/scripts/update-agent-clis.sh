#!/bin/bash
# Update Omarchy's agent CLIs. Hermes sends stdout to Telegram.
set -euo pipefail
umask 077
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:/usr/local/bin:/usr/bin:/bin:$PATH"
unset OP_SERVICE_ACCOUNT_TOKEN OP_VAULT OP_FORMAT CODEX_API_KEY OPENAI_API_KEY
cd "$HOME"

state="${XDG_STATE_HOME:-$HOME/.local/state}/agent-cli-updates"
mkdir -p "$state"
exec 9>"$state/run.lock"
flock -n 9 || { echo 'CLI update failed: another update is running.' >&2; exit 1; }

# Keep package output local. A failed command still fails the Hermes job.
exec 3>&1 >"$state/last-run.log" 2>&1
finish() {
    result=$?
    if [ "$result" -ne 0 ]; then
        printf 'Failed with exit %s at %s\n' "$result" "$(date -Is)"
        printf 'CLI update failed (exit %s). Read %s/last-run.log.\n' "$result" "$state" >&3
    fi
}
trap finish EXIT
printf 'Started at %s\n' "$(date -Is)"

# The launchers register missing tools through Omarchy's installation route.
# They also set the same release-age policy as an interactive launch.
codex --version
claude --version
export MISE_MINIMUM_RELEASE_AGE=0
mise upgrade --yes --global --no-prune codex claude </dev/null

codex_version="$(codex --version)"
claude_version="$(claude --version)"
versions="$(printf '%s\n%s' "$codex_version" "$claude_version")"
printf '%s\n' "$versions"
printf 'Succeeded at %s\n' "$(date -Is)"

# Compare with the last successful check, including any launcher updates.
previous=''
if [ -f "$state/versions" ]; then
    previous="$(cat "$state/versions")"
fi
printf '%s\n' "$versions" >"$state/versions.next"
mv "$state/versions.next" "$state/versions"
if [ "$versions" != "$previous" ]; then
    printf 'Agent CLI versions on %s:\n%s\n' "$(hostname)" "$versions" >&3
fi
