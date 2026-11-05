# Git

Version control practices for this public dotfiles repository.

## Atomic commits

- Each commit MUST contain one coherent change, with the documentation needed to explain it.
- Group interdependent files by observable behavior, not by file type. Do not split a change so that a commit depends on uncommitted work to function.
- Review the full intended delta before committing. Existing staging belongs to its owner and blocks publication. Do not reorganize, unstage, or consume another session's staging.
- Avoid WIP dumps and unrelated changes in one commit. A change spanning many files can still be atomic when it produces one outcome.
- Validate the actual commit candidate. Checks that depend on additional unstaged changes do not validate that commit.

## Implementation identity

Use BerryBolt as both author and committer and sign with its 1Password SSH key. Push candidates using BerryBolt SSH authentication. The public workflow and scope of local overrides are in the ignored local `PLAN.md` (when present); private key references and local access evidence stay in ignored local notes.

Keep the operator's global Git and GitHub CLI configuration unchanged. Installation fixture identities do not determine public commit attribution. Verify author, committer, signing status, and SSH account before publishing candidate commits.

## Commit messages

Use Conventional Commits: `<type>[optional scope]: <description>`.

Examples:

```text
docs: define Omarchy fundamentals and GitHub validation
refactor: bootstrap Omarchy without an agent harness
fix: restore credential env through reapply
feat: install a selected dotfiles revision from GitHub
```

## Destination and rollout

The intended destination is the remote default branch unless the owner selects a PR or another branch. A missing upstream or ambiguous destination blocks publication.

Normal delivery uses coherent atomic commits on `main`. The owner may authorize a candidate/test-ref exception. Under that exception, publish workspace prerequisites first, then setup candidates. Install the pushed full setup SHA with its matching installer on the disposable Omarchy environment. Complete live acceptance before merging, and obtain explicit rollout authority. Follow [the candidate and acceptance runbook](../runbooks/publication.md).

Every push to `main` publishes the installer and authorizes automatic setup rollout through the existing sync job. Workstations tracking it can apply within five minutes. A main push is not separate from deployment.

The machine's `data.dotfiles_branch` selects its setup tracking branch on `origin` and defaults to `main`. An explicitly selected candidate branch can receive updates through the same job on the disposable machine. Keep production on `main`. Selecting a branch does not waive candidate acceptance or rollout authorization.

- Push only locally checked commits. Run ShellCheck, Bash syntax checks on rendered scripts, Python parse checks, and the private-data review below.
- Do not create unit tests, fixture suites, or mocks. Use the existing acceptance scripts and live scenarios on the designated disposable Omarchy environment at pushed exact SHAs.
- Record exact revisions, observed results, and unperformed checks in the ignored local plan. Never describe a pushed candidate as runtime-accepted before its checks pass.
- Make fixes as new signed commits. Never amend pushed work.

## Publication in shared checkouts

Before reporting a durable change complete, publish reviewed whole files in the same session and verify the intended destination with a fresh remote read. New files and deletions count. Follow the workspace's `~/brain/policies/publication.md` and use `publish-reviewed`. The helper format is in [runbooks/publication.md](../runbooks/publication.md).

Record the root, branch, upstream, HEAD, intended paths, destination, and pre-existing edits before working. Preserve other sessions' work. The helper takes one publication lock per Git common directory, refuses staging, rechecks reviewed hashes, signs a `git commit --only`, verifies its actual tree and delta, pushes without force, fetches again, and verifies ancestry. Unrelated unstaged work may remain. Same-file edits need serial ownership and a fresh whole-file review. Partial-file publication is unsupported.

Fetch before integration. Fast-forward only when unrelated work is safe. If integration changes selected files, re-review and revalidate them. After a rejected push or divergence, retain the unpublished commit. For a manual signed merge, hold the same common-directory publication lock continuously through fetch, inspection, and merge. Require a clean checkout and recheck the inspected branch and HEAD immediately before merging the exact inspected remote SHA. Release the lock, then review and run required validation before invoking the helper again. Follow the workspace's manual merge procedure. Conflicts or unrelated staged or unstaged work block integration. Never rebase or autostash.

For direct delivery, a fresh destination must contain the published commit according to `git merge-base --is-ancestor`. A newer descendant is valid. PR work is "pushed, not landed" until GitHub reports a merge. Record the merge result and verify it on the default branch. Squash merges do not need to retain the original SHA.

Interrupted or unattributed dotfiles work requires owner resolution. Do not publish it unattended. Existing task records, file age, changed-file instructions, or a clean index alone cannot authorize someone else's changes.

Checking out old history can overwrite or delete now-ignored inputs such as `PLAN.md`. Preserve those inputs before any authorized historical checkout.

## Prohibited operations

- MUST NOT rebase.
- MUST NOT force push.
- MUST NOT use `git reset --hard` or discard unfinished work.
- MUST NOT amend pushed commits.

## Tracked content

Commit source templates, bootstrap scripts, acceptance scripts, policies, skills, and documentation belonging to the change.

Do not commit real secrets/tokens, SSH private keys, machine-local chezmoi configuration, credential env files, volatile runtime state, large binaries, or OS-generated files. Do not commit disposable login credentials, machine addresses, private infrastructure names/topology, private repository links, or live vault layouts. Keep these in ignored local inputs. Public keys and generic variable names are not secret; private keys and real access values are.

Before pushing, inspect both the actual staged diff and the committed candidate for private operational data. Ignore rules do not remove data already staged or tracked. Never force-add `PLAN.md`, `.env`, `tests/.env.local`, or `.local/`.
