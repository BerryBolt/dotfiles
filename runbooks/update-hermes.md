# Update Hermes

Hermes stays at the release that `home/.chezmoiscripts/run_once_before_50-install-hermes.sh` pins. Do not run `hermes update`, Hermes' installer, or Git commands in `~/.hermes/hermes-agent`. `hermes update` moves the checkout to Hermes' `main` branch and skips the acceptance checks. A release can drop a safety control, such as the `tirith` command scan, and only the checks show it.

Run this procedure from a terminal session on the workstation, such as a T3 Code thread. Do not run it from a gateway turn. The procedure restarts the gateway, and Hermes blocks a gateway turn from restarting its own gateway.

The monthly `hermes-release-check` job sends a Telegram notice when the newest stable release differs from the pin. To check now, run `hermes cron run hermes-release-check`.

## Update

Finish these steps within the hour. The unpushed pin commit defers repository synchronization, and an unchanged deferral wakes sync repair after an hour.

1. Select the newest stable release. A stable release tag has the form `vX.Y.Z` with no suffix. Read its commit from the peeled `^{}` line:

   ```bash
   git ls-remote --tags https://github.com/NousResearch/hermes-agent 'refs/tags/vX.Y.Z*'
   ```

2. Back up Hermes' state. The backup excludes the Hermes code, which step 7 can reinstall:

   ```bash
   backup=~/hermes-state-backup-$(date +%Y%m%dT%H%M).tar.gz
   tar -C ~ --exclude=.hermes/hermes-agent --exclude=.hermes/tools --exclude=.hermes/cache \
     --exclude=.hermes/sandboxes -czf "$backup" .hermes
   chmod 600 "$backup"
   ```

   `tar` reports that it ignores sockets. That is expected.

3. In the dotfiles source, set `HERMES_COMMIT` to the release commit and update the version comment above it. Commit the change with a signed commit, such as `chore: pin Hermes vX.Y.Z`. Do not push it yet. A push to `main` rolls the release out to every workstation that tracks it.

4. Apply the change. The changed pin runs apply script 50 again, and the gateway script restarts the gateway:

   ```bash
   chezmoi-with-op apply
   ```

5. Run the acceptance checks against the commit:

   ```bash
   cd "$(git -C "$(chezmoi source-path)" rev-parse --show-toplevel)"
   CHEZMOI_AGENT_EMAIL="$(chezmoi data --format json | jq -r .agent_email)" \
   CHEZMOI_AGENT_HANDLE_GITHUB="$(chezmoi data --format json | jq -r .agent_handle_github)" \
   CHEZMOI_AGENT_WORKSPACE_REPO="$(git -C ~/brain remote get-url origin | sed -E 's#^git@github.com:##; s#\.git$##')" \
   EXPECTED_REVISION="$(git rev-parse HEAD)" bash tests/assertions.sh
   ```

6. If every check passes, push the commit and verify it on the remote with `~/brain/policies/publication.md`. Report the new release to the owner. Delete the backup after a week without problems.

7. If a check fails, roll back. First confirm that `git log origin/main..HEAD` lists only the pin commit and that `git status --short` is empty. Then remove the commit and reinstall the pinned release:

   ```bash
   git reset --hard HEAD~1
   bash home/.chezmoiscripts/run_once_before_50-install-hermes.sh
   ```

   chezmoi does not run a script again for content that it already ran, so run apply script 50 directly. If a newer release replaced the launcher or the gateway unit, the checks fail on them. In that case, move the failing file aside and reinstall:

   ```bash
   systemctl --user stop hermes-gateway.service
   mv ~/.local/bin/hermes ~/hermes-launcher.failed
   mv ~/.config/systemd/user/hermes-gateway.service ~/hermes-gateway.service.failed
   bash home/.chezmoiscripts/run_once_before_50-install-hermes.sh
   hermes gateway install --start-on-login --no-start-now
   systemctl --user daemon-reload
   systemctl --user start hermes-gateway.service
   ```

   Run `chezmoi-with-op apply` and the checks from step 5 again. If Hermes cannot read its state, stop the gateway, restore the backup over `~/.hermes`, and start the gateway. Report the release and its failing checks to the owner.
