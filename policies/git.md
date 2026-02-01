# Git

Version control practices for the dotfiles repo.

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>[optional scope]: <description>

[optional body]
```

Common types: `feat`, `fix`, `docs`, `refactor`, `chore`

Examples:
```
feat: add mise config for node/python versions
fix: chezmoi template syntax for openclaw.json
refactor: reorganize repo with home/ as chezmoi root
docs: update credentials policy with strict invariants
chore: add starship and zoxide to Brewfile
```

## Atomic commits

- Each commit SHOULD contain one logical change
- Group related changes together (e.g., new dotfile + its template variables)
- MUST NOT mix unrelated changes in one commit
- If a change spans multiple files for one purpose, that's one commit

## Sync with upstream

- MUST pull before starting work: `git -C ~/.local/share/chezmoi pull`
- MUST push after each commit (or batch of related commits)
- SHOULD NOT leave uncommitted changes overnight

## Prohibited operations

- MUST NOT rebase
- MUST NOT force push (`--force`, `-f`)
- MUST NOT reset (`git reset --hard`)
- MUST NOT amend pushed commits

## What to commit

MUST commit:
- All dotfiles in `home/`
- Templates (`.tmpl` files)
- Policies and skills
- Brewfile
- run_once scripts

MUST NOT commit:
- Secrets or tokens (use 1Password + templates)
- `~/.config/chezmoi/chezmoi.toml` (machine-specific, has token)
- Large binary files
- OS-generated files (`.DS_Store`)

## Commit workflow

```bash
# Check status
git -C ~/.local/share/chezmoi status

# Stage specific files
git -C ~/.local/share/chezmoi add home/dot_zshrc

# Commit
git -C ~/.local/share/chezmoi commit -m "feat: add zoxide aliases"

# Push
git -C ~/.local/share/chezmoi push
```
