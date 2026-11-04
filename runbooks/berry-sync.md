# Repository synchronization

## Automatic behavior

The Hermes job `dotfiles-berry-sync` checks `~/brain` and the chezmoi source every five minutes. Clean tracking branches advance by fast-forward. Dotfiles applies with closed stdin and `--force=false`. Successful checks are silent. Blocked or failed checks wake the agent in the same job with the repository and a sanitized reason. Hermes keeps that job in flight throughout repair, so repeated ticks do not start concurrent repairs. Registration preserves its ID and paused state.

Dirty, detached, ahead, and diverged checkouts need repair or coordination with their owner. They are never automatically stashed, reset, committed, or pushed. An active sync or installer holds a shared lock and causes a silent scheduled skip. Other editors and manual chezmoi commands do not honor that lock.

Failed or interrupted applies retry at the same SHA at most hourly on schedule. The agent still wakes to diagnose a deferred retry. A new SHA or manual run retries immediately. The successful SHA in `~/.local/state/berry-sync/applied-sha`, under `XDG_STATE_HOME` when set, suppresses another apply at that SHA. Use manual chezmoi apply for target repairs or secret rotation without a source change.

## Manual sync and repair

```bash
berry-sync
```

A manual run exits nonzero when incomplete. Prioritize repair, inspect the named repository, and preserve other sessions' work. Coordinate before touching an active session's edits. Never discard edits to deploy new configuration. Git and apply errors expose only the command name and exit code, not raw output that may contain secrets.

After repair, run `berry-sync` again and verify the repository state and effective configuration. Apply can make partial progress. A newly managed path has no recorded chezmoi state and may replace existing content without prompting. Inspect its destination and preserve content before publishing it.

## Capture configuration choices

For a whole non-template file, capture the live choice into source:

```bash
chezmoi re-add ~/.some-config
```

For shared configuration, edit the source template and add the intended setting to its declared keys:

```bash
chezmoi edit ~/.hermes/config.yaml
chezmoi edit ~/.codex/config.toml
chezmoi edit ~/.claude/settings.json
```

Review the source change locally, commit only your changes, and push. Never capture runtime state or secrets. Do not print secret-bearing rendered files or diffs into logs. Apply and verify:

```bash
chezmoi-with-op --no-tty --force=false apply
chezmoi-with-op verify --exclude=scripts
berry-sync
```

## Recovery limits and acceptance

A stopped gateway cannot check or wake an agent. Recover it manually. A queued gateway restart is not proof that new configuration loaded. Restarts or Hermes upgrades can interrupt repair. Preserve recovery notes before restarting, then verify the gateway and its effective configuration. Pinned detached installations need an operator to select a tracking branch.

On an authorized disposable Omarchy account, extend the existing acceptance run with silent success, dirty and detached checkouts, ahead and diverged branches, failed apply, deferred retry, manual retry, and an unexpected script failure. Confirm each issue wakes repair with its repo and reason. Keep a repair turn active across multiple ticks and confirm no second repair starts. Apply twice and confirm one job with the same ID, unchanged unrelated jobs, and preserved paused state. Exercise a script update, gateway restart, and Hermes upgrade during sync, then verify recovery. Local syntax checks and source inspection do not prove these deployed behaviors.
