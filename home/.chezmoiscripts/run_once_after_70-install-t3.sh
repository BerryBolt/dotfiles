#!/bin/bash
# Install the pinned T3 CLI and its user service once per script revision.
# Reapplying unchanged dotfiles does not interrupt running T3 threads.
set -euo pipefail

T3_VERSION=0.1.6
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
# Apply has the service-account token. Neither the installer nor the service
# should inherit it, or API keys that override the provider subscription.
unset OP_SERVICE_ACCOUNT_TOKEN OP_VAULT OP_FORMAT CODEX_API_KEY OPENAI_API_KEY

installer="$(mktemp)"
trap 'rm -f "$installer"' EXIT
curl -fsSL https://t3.codes/install.sh -o "$installer"
T3CODE_VERSION="$T3_VERSION" sh "$installer" </dev/null
if [ "$(t3 --version)" != "t3 v$T3_VERSION" ]; then
    echo "Error: T3 Code does not match the declared version." >&2
    exit 1
fi

user="$(id -un)"
if [ "$(loginctl show-user "$user" --property=Linger --value)" != yes ]; then
    sudo -n loginctl enable-linger "$user"
fi
# T3 owns its generated unit. New services listen locally; the desktop can
# connect over SSH without opening a network listener or a cloud account.
t3 service install </dev/null
# `t3 service status` exits 0 whatever it reports, so it cannot prove this.
if ! systemctl --user is-active --quiet t3code.service; then
    echo "Error: the T3 Code service is not running. See \`t3 service status\`." >&2
    exit 1
fi
