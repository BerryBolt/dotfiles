# Agent CLI updates

Chezmoi manages the update script and registers `update-agent-clis` in Hermes on every apply. Hermes runs it daily at 09:15 in its scheduler timezone, without a model call.

The script uses Omarchy's launchers to register missing tools, then runs `mise upgrade --yes --global --no-prune codex claude`. It follows Omarchy's `latest` versions and release-age setting. It retains previous installations for running sessions and does not restart services. New CLI processes use the updated versions.

The first successful check sends both versions to Telegram. Later checks send a message only when the versions change. Failed checks exit nonzero and Hermes reports the failure. A stopped Hermes gateway cannot run the job or send notices.

## Check an update

1. Run `hermes cron list` to find the job and its next run.
2. Run `hermes cron run update-agent-clis` to request a check.
3. Run `hermes cron runs update-agent-clis --limit 5` to inspect completion and delivery.
4. Read `~/.local/state/agent-cli-updates/last-run.log` for the latest command output and versions.

If `XDG_STATE_HOME` is set, the log is under `$XDG_STATE_HOME/agent-cli-updates` instead. The same directory holds the last successful versions and the update lock. These files are runtime state and stay outside Git. Hermes retains its own run history, including silent checks.

For a direct check outside Hermes, run `bash ~/.hermes/scripts/update-agent-clis.sh`. This command records the result locally and prints notices, but sends no Telegram message.

## Reapply and recovery

Reapply restores the script and corrects the job's schedule and delivery settings. It preserves an intentional pause and stops if duplicate jobs exist. To resume a paused job, use its ID from `hermes cron list` with `hermes cron resume <job-id>`.

After a failed check, read the log, fix the reported cause, and request another check. Do not run another installer or change CLI version declarations outside Omarchy's route. See the [dependency policy](../policies/dependencies.md).
