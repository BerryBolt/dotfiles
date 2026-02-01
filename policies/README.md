# Policies

Self-serve operations manual for managing this environment.

## Single source of truth

**One source of truth for everything. No duplication.**

| What | Source of truth |
|------|-----------------|
| Secrets | 1Password |
| CLI tools | `~/.config/mise/config.toml` |
| GUI apps / system deps | `Brewfile` |
| Dotfiles | chezmoi source (`~/.local/share/chezmoi/home/`) |
| Policies | This directory |

MUST NOT duplicate definitions. If it exists in the source of truth, reference it — don't copy it.

## Normative language (RFC 2119/8174)

- **MUST:** Absolute requirement.
- **MUST NOT:** Absolute prohibition.
- **SHOULD:** Strong recommendation; deviate only with a valid, documented reason.
- **SHOULD NOT:** Strong discouragement; deviate only with a valid, documented reason.
- **MAY:** Permission; allowed but not required.

## Policy documents

| Document | Purpose |
|----------|---------|
| [dependencies.md](dependencies.md) | Package management (mise, Homebrew) |
| [credentials.md](credentials.md) | 1Password operations, compliance |
| [dotfiles.md](dotfiles.md) | chezmoi operations |
| [git.md](git.md) | Version control practices |

## Tools

| Tool | Purpose | Docs |
|------|---------|------|
| **mise** | Package manager for CLI tools | https://mise.jdx.dev |
| **chezmoi** | Dotfiles management, templating | https://chezmoi.io |
| **1Password CLI (`op`)** | Secrets management | https://developer.1password.com/docs/cli |
| **git** | Version control for dotfiles | - |
| **Homebrew** (macOS) | GUI apps, system dependencies | https://brew.sh |
