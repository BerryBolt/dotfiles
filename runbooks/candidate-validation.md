# Candidate validation

## Candidate and rollout gate

The owner may authorize a candidate/test-ref workflow instead of normal direct-main delivery. Record that scope in the ignored local plan before implementation. Keep candidates off `main` until acceptance passes and rollout is authorized. Publish workspace prerequisites to their candidate before setup candidates that reference them. Do not include pre-existing unowned edits.

Merging setup to `main` authorizes automatic rollout through the existing five-minute job and the public installer. A main push is not separate from deployment. After acceptance and explicit rollout authorization, merge workspace prerequisites first, then setup. For PR landing, read GitHub's merged state and merge commit, fetch the default branch, and verify that merge result is its ancestor. Squash merges need not retain the branch SHA.

On the disposable Omarchy environment, download `install.sh` from the pushed full setup SHA and pass that same SHA to `--revision`. Fetch and select the pushed workspace candidate explicitly. Record both SHAs. Do not install an uncommitted tree. Preserve test access and the Omarchy baseline. Reset only the authorized disposable setup between fresh-install attempts.

Before a full install that starts services, confirm a separate test delivery identity and destination. Before agent scenarios, also confirm independent Codex CLI and Hermes device sign-ins. Never copy OAuth credentials or run another gateway against the production bot. If those prerequisites are absent, complete independent component checks and report the missing prerequisite. Do not claim full install, repair delivery, or agent acceptance.

## Rollback

Keep failed candidates off `main`. After rollout, revert faulty source with a new commit, then verify apply. Preserve the existing job and durable files. Do not restore old runtime databases or reset workspaces.
