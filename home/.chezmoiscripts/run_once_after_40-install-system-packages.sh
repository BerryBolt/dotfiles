#!/bin/bash
# System packages this repo adds beyond Omarchy's base, installed with
# Omarchy's package commands, which skip what is already present. Runs again
# when this file changes. Needs the passwordless sudo from script 20.
# See policies/dependencies.md.

set -euo pipefail

# Omarchy's commands read OMARCHY_PATH, which only login and interactive shells set.
# shellcheck disable=SC1091
. /usr/share/omarchy/default/bash/env-bootstrap

# Brave holds the agent's synced browser profile. Omarchy's installer adds it
# from the AUR with Omarchy's browser flags and theme policy.
if ! pacman -Q brave-bin >/dev/null 2>&1; then
    omarchy-install-browser brave
fi
# The same call omarchy-default-browser makes; that command then sends a
# desktop notification, which fails without a graphical session.
env -u BROWSER xdg-settings set default-web-browser brave-browser.desktop
if [[ "$(env -u BROWSER xdg-settings get default-web-browser)" != brave-browser.desktop ]]; then
    echo "Error: could not make Brave the default browser." >&2
    exit 1
fi
echo "Brave is installed and is the default browser."
