# Scheduled handbook release

This integration runs a repository's draft-release check through Hermes. The repository owns its release settings, code, dependencies, and publication instructions. Dotfiles owns the scheduler registration and the managed script link. Runtime jobs and session logs stay outside Git.

## Configure the checkout

Clone the selected updater repository with the machine's GitHub account. That account needs access to the updater and release repository. Follow the updater's README for its required permissions and model sign-in. Never copy model authentication files between machines.

Set `data.handbook_updater_checkout` to the updater's absolute checkout path through `chezmoi edit-config`. The checkout must contain `release.py`, `config.yml`, and `scripts/handbook-release.sh`. The release code runs in Hermes' existing Python environment. The updater declares the YAML dependency that environment must supply.

Review `chezmoi-with-op diff` for the new script link and registration script. Exclude secret-bearing files from logged diffs. Apply those two source paths with `chezmoi-with-op apply --source-path`. Apply registers one `handbook-release` job. Registration preserves the job's ID and paused state. The job runs its script without a Hermes model call and keeps output locally.

The repository's script controls when its release model starts. Its `config.yml` controls enablement, schedule, model, effort, and retries. The default empty checkout value leaves this integration unconfigured on other machines. Changing that value does not delete an existing job. Before removing the integration, pause its job with `hermes cron pause <job-id>`.

## Verify the job

Use `hermes cron list` to find the job. Use `hermes cron runs <job-id>` to inspect its executions. Check the updater's saved result and the actual release on GitHub before reporting publication. A registered job alone does not prove that a release succeeded.
