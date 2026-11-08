#!/bin/bash
# Hermes' cron runs this script monthly with no model call and sends its output
# to Telegram. It prints a notice when the newest stable Hermes release differs
# from the commit that apply script 50 pins. No output sends no message.
set -euo pipefail
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

repo=https://github.com/NousResearch/hermes-agent
source_root="$(git -C "$(chezmoi source-path)" rev-parse --show-toplevel)"
pin="$(sed -n 's/^HERMES_COMMIT=//p' "$source_root/home/.chezmoiscripts/run_once_before_50-install-hermes.sh")"
[ -n "$pin" ] || { echo "Error: apply script 50 pins no Hermes commit." >&2; exit 1; }

# Stable releases are vX.Y.Z tags without a suffix. The one- to three-digit
# major excludes the older date tags, such as v2026.9.24.
tags="$(git ls-remote --tags "$repo")"
latest="$(printf '%s\n' "$tags" |
  sed -n 's#^[0-9a-f]*\trefs/tags/\(v[0-9]\{1,3\}\.[0-9]\{1,\}\.[0-9]\{1,\}\)$#\1#p' |
  sort -V | tail -n 1)"
[ -n "$latest" ] || { echo "Error: Hermes has no stable release tag." >&2; exit 1; }

# The peeled ^{} line holds an annotated tag's commit.
commit="$(printf '%s\n' "$tags" | awk -v t="refs/tags/$latest^{}" '$2 == t { print $1 }')"
[ -n "$commit" ] || commit="$(printf '%s\n' "$tags" | awk -v t="refs/tags/$latest" '$2 == t { print $1 }')"
[ "$commit" = "$pin" ] && exit 0

host="$(hostname)"
echo "Hermes $latest is out. $host pins Hermes commit ${pin:0:7}. To update, open a T3 Code thread on $host and ask it to follow runbooks/update-hermes.md in dotfiles."
