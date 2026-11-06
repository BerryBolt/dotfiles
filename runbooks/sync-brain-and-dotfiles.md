# Repository synchronization

Your Hermes job checks brain and dotfiles every five minutes. Successful checks stay silent. An unchanged failure wakes repair at most hourly. The job repairs only its own changes and reports other sessions' retained work for owner resolution.

## Run now and inspect history

Start the existing Hermes job manually so the execution appears in its history:

```bash
hermes cron run sync-brain-and-dotfiles
hermes cron list
hermes cron runs <job-id> --limit 20
```

Use the ID shown by `hermes cron list`. A dispatched run is not proof that sync completed. Inspect its result. This runs the same scheduled checks, including retry and repair suppression.

Hermes stores run documents under `~/.hermes/cron/output/<job-id>/`. Silent checks record that the agent was skipped, but do not retain detailed script output or before-and-after commits. Hermes keeps the latest 50 run documents by default. No separate sync log is maintained.

Use the direct `sync-brain-and-dotfiles` command during repair or when Hermes is unavailable. It bypasses failed-apply retry suppression. Do not launch the Hermes job recursively. If direct sync reports another run is active, record the blocker and return without polling.

## Fix blocked sync

Read the reported repository and reason, then inspect the current checkout. Dirty, detached, ahead or diverged checkouts and missing upstreams defer sync. Preserve other sessions' edits and staging. Publish only work you made for this repair through the standard Git procedure in `~/brain/policies/publication.md`. Other sessions' unfinished work requires owner resolution. Follow [candidate validation](candidate-validation.md) before setup rollout.

Run sync immediately after repair:

```bash
sync-brain-and-dotfiles
```

A nonzero exit means sync is incomplete. Verify the repository state and applied configuration before calling the repair complete. Manual sync retries a failed apply immediately. Scheduled applies retry the same commit at most hourly.

If you need the owner, report the repository, reason, and exact action needed. The job delivers your final response to Telegram. Reply `[SILENT]` when nothing new needs reporting. Keep unresolved ownership, next action, and the known task reference in the job notepad. Avoid repeating unchanged reports while the job continues its bounded internal retries.

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

Add only the intended setting to the template's declared keys. Preserve unrelated settings. Review and validate the source delta, then commit and push through the workspace procedure. Never capture secrets or runtime state.

Apply and verify your configuration:

```bash
chezmoi-with-op --no-tty --force=false apply
chezmoi-with-op verify --exclude=scripts
sync-brain-and-dotfiles
```

Before adding a newly managed path, inspect its destination and preserve existing content. Chezmoi may replace that content without prompting.

## Recover the gateway

A stopped gateway cannot sync or wake you. Recover it manually, then run `sync-brain-and-dotfiles`. Verify the gateway and effective configuration after a restart. Pulling brain files does not prove that an existing conversation loaded its new instructions.

Before restarting during repair, find `sync-brain-and-dotfiles` with `hermes cron list` and save recovery notes with `hermes cron notepad <id> set recovery <text>`.

A pinned detached installation requires an operator to check out its intended tracking branch. Report this block rather than choosing a branch yourself. The branch must match `data.dotfiles_branch` in chezmoi configuration, which defaults to `main` for older configurations. Set `CHEZMOI_DOTFILES_BRANCH` on an installer run to save another selection. A normal installer run can switch clean published branches, but never moves a detached source. Keep production on `main` and retain the candidate acceptance gate.

## Sync limits

The job checks the current checkouts independently. It does not scan stashes, other branches or secondary worktrees. Dirty checkouts defer before fetching. The installer and sync share `run.lock`; editors do not acquire it. Sync rechecks the branch and source before apply and checks again afterward. If source changes during apply, it does not record success; a later clean run retries.

Setup apply requires the saved `dotfiles_branch` and its matching origin upstream. The default is `main`. A source with local commits cannot be auto-applied. Explicit revision-pinned installs remain available for testing.

Sync does not render credential-dependent templates to detect live changes. Run `chezmoi-with-op verify --exclude=scripts` after setup work and capture intended settings in source. Scheduled-definition recovery and external-action replay remain outside this increment.
