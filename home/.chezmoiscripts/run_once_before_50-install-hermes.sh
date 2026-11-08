#!/bin/bash
# Hermes Agent, the agent's harness, installed with Hermes' own installer at a
# pinned release: a git checkout in ~/.hermes/hermes-agent and the `hermes`
# command in ~/.local/bin. Runs again when this file changes, so changing the
# pin moves the install to that commit, forward or back.

set -euo pipefail

# Hermes Agent v0.23.0 (tag v0.23.0).
HERMES_COMMIT=2bd378ed1b8d6bf2192cb26e0a55ff3091e6bd19

# mise's shims give the installer Omarchy's Node, so it does not download its
# own.
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

installer="$(mktemp)"
trap 'rm -f "$installer"' EXIT
curl -fsSL "https://raw.githubusercontent.com/NousResearch/hermes-agent/$HERMES_COMMIT/scripts/install.sh" \
    -o "$installer"

# Run only the stages that need no answers. The installer would otherwise run
# its setup wizard and offer the gateway service whenever a terminal is
# attached; Hermes' configuration and service belong to this repository.
# --commit keeps the pin over the installer's release channel. The Computer
# Use driver is left out: it comes from a third-party installer on that
# project's main branch, and Hermes installs it when the tool is enabled.
stages="$(bash "$installer" --manifest | jq -r '.stages[] | select(.needs_user_input | not) | .name')"
for stage in $stages; do
    bash "$installer" --stage "$stage" --non-interactive --commit "$HERMES_COMMIT" \
        --skip-computer-use </dev/null
done

# The installer appends a ~/.local/bin PATH block to each shell startup file
# that has no PATH line for it. The account's shell setup already puts
# ~/.local/bin on PATH, and these files are not Hermes', so remove exactly that
# block. A file that only the block created is removed.
path_line='case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac'
for rc in "$HOME/.bashrc" "$HOME/.profile" "$HOME/.bash_profile" "$HOME/.bash_login"; do
    [ -f "$rc" ] || continue
    python3 - "$rc" "$path_line" <<'PY'
import pathlib, sys
rc = pathlib.Path(sys.argv[1])
block = "\n# Hermes Agent command\n" + sys.argv[2] + "\n"
text = rc.read_text()
if block in text:
    text = text.replace(block, "")
    if text:
        rc.write_text(text)
    else:
        rc.unlink()
PY
done

if [ "$(git -C "$HOME/.hermes/hermes-agent" rev-parse HEAD)" != "$HERMES_COMMIT" ]; then
    echo "Error: Hermes is not at the pinned commit $HERMES_COMMIT." >&2
    exit 1
fi
hermes --version
