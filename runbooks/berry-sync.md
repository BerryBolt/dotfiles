# Repository synchronization

Your Hermes job `dotfiles-berry-sync` checks brain and dotfiles every five minutes while the gateway runs. Successful checks stay silent. A blocked or failed sync wakes you to prioritize repair. An unchanged issue wakes you at most hourly. Hermes keeps the repair in the same job to prevent overlapping repair turns.

## Fix blocked sync

Inspect the named repository and reason. Preserve other sessions' edits and coordinate with their owner. Commit and push your own completed work. Resolve divergence after inspecting both sides. Never stash, reset, or discard someone else's work to make sync pass.

Run sync immediately after repair:

```bash
berry-sync
```

A nonzero exit means sync is incomplete. Verify the repository state and applied configuration before calling the repair complete. Manual sync retries a failed apply immediately. Scheduled applies retry the same commit at most hourly.

If you need the owner, report the repository, reason, and exact action needed. The job delivers your final response to Telegram. Reply `[SILENT]` when nothing new needs reporting. Use the job notepad to avoid repeating unchanged reports.

For an apply failure, inspect the error locally by running `chezmoi-with-op --no-tty --force=false apply`. Treat its output as sensitive. Do not copy credentials, rendered files, or raw command output into reports.

## Save configuration choices

Prefer changing dotfiles source first, then applying it. To capture a live change to a whole non-template file, run:

```bash
chezmoi re-add ~/.some-config
```

For shared configuration, find its source template and edit the returned path with your file-editing tool:

```bash
chezmoi source-path ~/.hermes/config.yaml
chezmoi source-path ~/.codex/config.toml
chezmoi source-path ~/.claude/settings.json
```

Add only the intended setting to the template's declared keys. Preserve unrelated settings. Review the source diff, commit your changes, and push. Never capture secrets or runtime state.

Apply and verify your configuration:

```bash
chezmoi-with-op --no-tty --force=false apply
chezmoi-with-op verify --exclude=scripts
berry-sync
```

Before adding a newly managed path, inspect its destination and preserve existing content. Chezmoi may replace that content without prompting.

## Recover the gateway

A stopped gateway cannot sync or wake you. Recover it manually, then run `berry-sync`. Verify the gateway and effective configuration after a restart. Pulling brain files does not prove that an existing conversation loaded its new instructions.

Before restarting during repair, find `dotfiles-berry-sync` with `hermes cron list` and save recovery notes with `hermes cron notepad <id> set <text>`.

A pinned detached installation requires an operator to select its intended tracking branch. Report this block rather than choosing a branch yourself.
