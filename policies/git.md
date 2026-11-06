# Git

Version control practices for this public dotfiles repository.

## Atomic commits

- Each commit MUST contain one coherent change, with the documentation needed to explain it.
- Group interdependent files by observable behavior, not by file type. Do not split a change so that a commit depends on uncommitted work to function.
- Review the full intended delta before committing. Existing staging belongs to its owner. Stop if it overlaps your selected files. Do not reorganize, unstage, or consume another session's staging.
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

Normal delivery uses coherent atomic commits on `main`. The owner may authorize a candidate/test-ref exception. Under that exception, publish workspace prerequisites first, then setup candidates. Install the pushed full setup SHA with its matching installer on the disposable Omarchy environment. Complete live acceptance before merging, and obtain explicit rollout authority. Follow [the candidate and acceptance runbook](../runbooks/candidate-validation.md).

Every push to `main` publishes the installer and authorizes automatic setup rollout through the existing sync job. Workstations tracking it can apply within five minutes. A main push is not separate from deployment.

The machine's `data.dotfiles_branch` selects its setup tracking branch on `origin` and defaults to `main`. An explicitly selected candidate branch can receive updates through the same job on the disposable machine. Keep production on `main`. Selecting a branch does not waive candidate acceptance or rollout authorization.

- Push only locally checked commits. Run ShellCheck, Bash syntax checks on rendered scripts, Python parse checks, and the private-data review below.
- Do not create unit tests, fixture suites, or mocks. Use the existing acceptance scripts and live scenarios on the designated disposable Omarchy environment at pushed exact SHAs.
- Run `tests/assertions.sh` and `tests/recovery.sh` for the affected workstation behavior. Download `install.sh` from the pushed full SHA and pass that same SHA to `--revision`.
- Record exact revisions, observed results, and unperformed checks in the ignored local plan. Never describe a pushed candidate as runtime-accepted before its checks pass.
- Make fixes as new signed commits. Never amend pushed work.

## Publication in shared checkouts

Before reporting a durable change complete, commit and push the intended files with standard Git commands, then fetch to confirm the remote contains the commit. Follow `~/brain/policies/publication.md` for the command sequence. New files and deletions count. Review the actual signed commit and every earlier unpushed commit before pushing its explicit SHA.

Preserve other sessions' staging and edits. Use `git commit -S -m "<message>" -- <paths>` to commit selected whole files without consuming unrelated staging. Add new files explicitly first. If another session edits or stages the same file, coordinate before committing it.

After a rejected push, retain the commit. Fetch and inspect both sides. Merge only in a clean checkout with `git merge -S --no-autostash <reviewed-remote-SHA>`, then review and validate the result before pushing. Never rebase or autostash. Repair publishes only its own changes; other sessions' interrupted work waits for owner resolution.

Report PR work as "pushed, not landed" until GitHub reports a merge and a fresh fetch confirms its merge result on the default branch.

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
