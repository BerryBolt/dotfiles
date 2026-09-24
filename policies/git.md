# Git

Version control practices for this public dotfiles repository.

## Atomic commits

- Each commit MUST contain one coherent change, with the tests and documentation needed to explain and validate it.
- Group interdependent files by observable behavior, not by file type. Do not split a change so that a commit depends on uncommitted work to function.
- Review the full staged and unstaged delta before committing. Existing staging is not an approved commit boundary; reorganize it without discarding file contents.
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

## Public GitHub validation

The selected implementation workflow includes atomic commits and candidate-branch pushes to [BerryBolt/dotfiles](https://github.com/BerryBolt/dotfiles). Push a coherent, locally checked candidate before testing its installation on the disposable VM. Follow the ignored local `PLAN.md` (when present) for the exact sequence and target.

- Use an implementation branch for candidate commits. Testing does not require merging to `main` or changing the public bootstrap endpoint.
- Verify the full pushed SHA. The VM must retrieve both the installer and chezmoi source from that revision.
- Commit and push fixes as new commits. Reset the disposable VM test setup before each fresh-install attempt until installation passes; then complete the broader checks and final acceptance run.
- Record test evidence without real credentials or secret-bearing logs. Mark unperformed tests explicitly.
- Remote install evidence follows the candidate push; do not describe a published candidate as verified before its tests pass.

## Synchronization and staging

Check local changes and remote state before beginning work. Fetch and inspect divergence; fast-forward a clean branch where appropriate. Do not pull into this existing mixed working tree merely to satisfy a synchronization ritual.

Stage only the reviewed files or hunks for the intended commit. Confirm `git diff --cached` matches the logical change, then commit and push the candidate branch. Remaining local work must stay intact for subsequent commits.

## Prohibited operations

- MUST NOT rebase.
- MUST NOT force push.
- MUST NOT use `git reset --hard` or discard unfinished work.
- MUST NOT amend pushed commits.

## Tracked content

Commit source templates, bootstrap scripts, required tests, policies, skills, and documentation belonging to the change.

Do not commit real secrets/tokens, SSH private keys, machine-local chezmoi configuration, credential env files, volatile runtime state, large binaries, or OS-generated files. Do not commit disposable login credentials, machine addresses, private infrastructure names/topology, private repository links, or live vault layouts. Keep these in ignored local inputs. Public keys and generic variable names are not secret; private keys and real access values are.

Before pushing, inspect both the actual staged diff and the committed candidate for private operational data. Ignore rules do not remove data already staged or tracked. Never force-add `PLAN.md`, `.env`, `tests/.env.local`, or `.local/`.

Default-branch promotion, endpoint publication, and dedicated-workstation deployment remain distinct from pushing candidate commits for testing.
