#!/bin/bash
# Hermes Agent, the agent's harness, installed with Hermes' own installer at a
# pinned release: a git checkout in ~/.hermes/hermes-agent and the `hermes`
# command in ~/.local/bin. Runs again when this file changes, so changing the
# pin moves the install to that commit, forward or back.
# See policies/dependencies.md.

set -euo pipefail

# Hermes Agent v0.21.5 (tag v2026.9.24).
HERMES_COMMIT=f97608f178d1ffeca59860195ab7da295f7c8e5f

# mise's shims give the installer Omarchy's Node, so it does not download its
# own. With ~/.local/bin already on PATH, it adds no PATH line to ~/.bashrc.
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

installer="$(mktemp)"
trap 'rm -f "$installer"' EXIT
curl -fsSL "https://raw.githubusercontent.com/NousResearch/hermes-agent/$HERMES_COMMIT/scripts/install.sh" \
    -o "$installer"

# Run only the stages that need no answers. The installer would otherwise run
# its setup wizard and offer the gateway service whenever a terminal is
# attached; Hermes' configuration and service belong to this repository.
# --force-commit keeps the pin, because the installer first moves an existing
# checkout to Hermes' main. The Computer Use driver is left out: it comes from
# a third-party installer on that project's main branch, and Hermes installs
# it when the tool is enabled.
stages="$(bash "$installer" --manifest | jq -r '.stages[] | select(.needs_user_input | not) | .name')"
for stage in $stages; do
    bash "$installer" --stage "$stage" --non-interactive --commit "$HERMES_COMMIT" --force-commit \
        --skip-computer-use </dev/null
done

if [ "$(git -C "$HOME/.hermes/hermes-agent" rev-parse HEAD)" != "$HERMES_COMMIT" ]; then
    echo "Error: Hermes is not at the pinned commit $HERMES_COMMIT." >&2
    exit 1
fi
hermes --version
