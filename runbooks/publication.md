# Publication helper and candidate acceptance

Dotfiles installs `publish-reviewed`. The workspace owns [the publication procedure](~/brain/policies/publication.md). Follow it for scope, ownership, placement, and completion evidence. This runbook defines the helper's input and the setup validation gate.

## Reviewed input

Pass `--repo <checkout> --review <private-json-path> --message <commit-message>`. Use a JSON object with exactly these fields:

```json
{
  "branch": "test/publication-example",
  "head": "<full-reviewed-HEAD-SHA>",
  "remote": "origin",
  "destination": "test/publication-example",
  "paths": {
    "notes/example.md": {"sha256": "<SHA-256-of-reviewed-bytes>", "mode": "100644"},
    "notes/removed.md": null
  },
  "commits": []
}
```

Paths are literal whole files relative to the repository root. A deletion is `null`. Modes are `100644`, `100755`, or `120000`. For a symlink, hash its link text, not the target file. For an ordinary file, use its raw bytes and SHA-256. Parent symlinks, directories, submodules, and ignored new outputs are unsupported. Review the actual Git delta too, since attributes and filters can change the committed bytes. Such a mismatch blocks the push.

`commits` is the complete ordered list from `git rev-list --reverse <fresh-destination>..HEAD`. Review provenance, content, destination, signatures, and validation for every listed commit. An empty `paths` object publishes only those reviewed retained commits. Hashes and commit IDs identify your review; they cannot establish ownership or authorization.

The selected branch must track the selected remote branch. Configure the owner-selected destination before reviewing. The remote must already contain that branch, and its push URL must use SSH. The helper does not create destinations or change accounts, protocols, upstreams, or global settings. An operator creates an explicitly authorized candidate or test ref first.

The helper locks `publication.lock` in the Git common directory. All worktrees share this lock. Sync also takes it before integrating or applying. It refuses staged or conflicted work and rechecks branch, HEAD, selected files, and review hashes under the lock. It may preserve unrelated unstaged changes while committing selected whole files with `git commit -S --only`. New files receive intent-to-add entries for that command. A failed commit may leave those selected intent-to-add entries. Inspect them before retrying; never clear another session's staging.

After committing, the helper verifies the parent, complete delta, selected tree entries, raw content hashes, modes, deletions, and signature before pushing an immutable commit ID. A mismatch leaves an unpublished commit and requires a fresh review. A failed push triggers a fresh remote read and leaves the commit for review and retry. No automatic merge, rebase, autostash, force, reset, or override exists.

A clean checkout that is behind may fast-forward, then stops for review and validation of the new state. Dirty or diverged checkouts block integration. Follow the workspace procedure for a signed merge and revalidation. The helper fetches again after pushing and checks ancestry. It prints JSON with the repository, branch, published commit, destination, fetched commit, and proof. Keep this in the task record. Application and VM acceptance require separate evidence.

## Candidate and rollout gate

The owner may authorize a candidate/test-ref workflow instead of normal direct-main delivery. Record that scope in the ignored local plan before implementation. Keep candidates off `main` until acceptance passes and rollout is authorized. Publish workspace prerequisites to their candidate before setup candidates that reference them. Do not include pre-existing unowned edits.

Merging setup to `main` authorizes automatic rollout through the existing five-minute job and the public installer. A main push is not separate from deployment. After acceptance and explicit rollout authorization, merge workspace prerequisites first, then setup. For PR landing, read GitHub's merged state and merge commit, fetch the default branch, and verify that merge result is its ancestor. Squash merges need not retain the branch SHA.

On the disposable Omarchy environment, download `install.sh` from the pushed full setup SHA and pass that same SHA to `--revision`. Fetch and select the pushed workspace candidate explicitly. Record both SHAs. Do not install an uncommitted tree. Preserve test access and the Omarchy baseline. Reset only the authorized disposable setup between fresh-install attempts.

Before a full install that starts services, confirm a separate test delivery identity and destination. Before agent scenarios, also confirm independent Codex CLI and Hermes device sign-ins. Never copy OAuth credentials or run another gateway against the production bot. If those prerequisites are absent, complete independent component checks and report the missing prerequisite. Do not claim full install, repair delivery, or agent acceptance.

## Live acceptance

Use real Git remotes and designated test-owned refs. Never push scenario changes to production default branches. Do not create unit tests, fixture suites, or mocks. Record each command, before/after state, remote commit, result, and cleanup in the ignored local plan. Public summaries omit infrastructure, credentials, private repository links, and private content.

Run every scenario that requires an agent decision in three fresh sessions. Record all three outcomes separately. Three passes are acceptance evidence, not a reliability guarantee. Deterministic checks do not replace these sessions.

| Scenario | Steps and required evidence |
| --- | --- |
| Skills, notes, and deletion | Ask Hermes to create a harmless skill through its creation tool, edit a test note, and delete a test-owned file. Inspect returned canonical paths, ignore rules, reviewed hashes, publication proof, a fresh checkout, and a subsequent session loading the skill. |
| Scoped instruction loading | Start fresh Codex and Claude sessions outside brain and dotfiles, and fresh Hermes sessions. Have each identify the loaded writing and publication instructions and publish an authorized test change in scope. Use another repository to confirm its own workflow remains in force. Retain session evidence and remote commits. |
| Placement errors | Have each writer identify an ignored or misplaced durable output and correct its canonical output path. Confirm raw content remains ignored. Inspect Hermes' actual create and read paths, including its command and startup skill loader, not just config. |
| Shared unstaged changes | Leave a test-owned unrelated unstaged edit. Publish only the selected file. Compare the unrelated bytes and Git diff before and after. Reproduce the selected content from a fresh fetch. |
| Staging and races | Leave another session's staged file and attempt publication. It must block without changing staging. Change a selected file after its review and require a hash block. Use a real concurrent editor or hook race to require a pre-push committed-content block. Verify no unreviewed commit reaches the destination. |
| Retained commit after push failure | Remove test connectivity after review and commit. Restore it, inspect the retained commit, and have the existing repair job publish with provenance and fresh remote proof. Retain job history and destination state. |
| Interrupted work | Interrupt a workspace task before and after commit. Verify record lookup connects paths and intent and establishes inactive ownership before takeover. Unattributed content and interrupted setup work must produce an owner-resolution block without publication. Plain CLI records may be missing; verify that block too. |
| Detector inventory | In real test checkouts, combine dirty files and unpushed commits, then add a secondary worktree, a branch without upstream, and a stash. Compare aggregate diagnostics with local Git inventory. Confirm no secondary publication, apply, or content loss. |
| Remote advancement and divergence | Advance the destination through a second real checkout. Verify direct ancestry proof accepts a newer descendant. Require clean integration, signed merge, review, and validation after divergence. Complete a designated test PR by squash and verify GitHub's merge result on the default branch. |
| Apply branch gate | Run the scheduled detector with detached, non-default, and unconfigured setup branches. It must report and defer apply. Verify explicit revision-pinned installer use still selects the exact SHA. |
| Bounded repair | Observe a transient edit once, then resolve it. No publication repair should wake. Leave an incident for two scheduled observations, then change dirty work into an ahead commit. Require one wake, hourly retries, and no immediate wake on the reason transition. A failed fetch must not clear the incident. Verify clean observation resets it. |
| Settings and recovery | Change a harmless rendered setting, require post-task verification to detect it, then capture the intended source and apply. Verify convergence without credentials or runtime data entering Git. Run existing assertions and recovery at the exact pushed SHA. |
| Reapply and restart | Save job identity, schedule, paused state, and history, reapply twice, restart the isolated gateway, and confirm one job retains them. Verify fresh sessions load current rules and a fresh checkout contains the durable content. |

The implementing operator removes test-owned files, refs, stashes, and secondary worktrees after recording evidence. Preserve failures and unfinished work until their ownership is resolved. Do not delete repositories or reset shared checkouts as cleanup.

## Rollback

Keep failed candidates off `main`. After rollout, revert faulty source with a new commit, then verify apply. Preserve the existing job and durable files. Do not restore old runtime databases or reset workspaces.
