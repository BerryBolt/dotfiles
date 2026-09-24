# Policies

Operational rules for the Omarchy user environment.

## Single source of truth

**One source of truth for everything. No duplication.**

| What                   | Source of truth                                 |
| ---------------------- | ----------------------------------------------- |
| Secrets                | 1Password                                       |
| System packages        | Omarchy / pacman (outside this repo)            |
| Bootstrap CLI tools    | `~/.config/mise/conf.d/dotfiles.toml` (from `home/dot_config/mise/conf.d/`) |
| Dotfiles               | chezmoi source (`~/.local/share/chezmoi/home/`) |
| Policies               | This directory                                  |

MUST NOT duplicate definitions. If it exists in the source of truth, reference it — don't copy it.

## Normative language (RFC 2119/8174)

- **MUST:** Absolute requirement.
- **MUST NOT:** Absolute prohibition.
- **SHOULD:** Strong recommendation; deviate only with a valid, documented reason.
- **SHOULD NOT:** Strong discouragement; deviate only with a valid, documented reason.
- **MAY:** Permission; allowed but not required.

## Policy documents

| Document                           | Purpose                                       |
| ---------------------------------- | --------------------------------------------- |
| [dependencies.md](dependencies.md) | What Omarchy supplies and what this repo adds |
| [credentials.md](credentials.md)   | 1Password operations, compliance              |
| [chezmoi.md](chezmoi.md)           | chezmoi operations and managed-file rules     |
| [git.md](git.md)                   | Version control practices                     |

## Tools

| Tool                     | Purpose                         | Docs                                     |
| ------------------------ | ------------------------------- | ---------------------------------------- |
| **Omarchy / pacman**     | Desktop, shell defaults, system packages (Git, OpenSSH, mise) | https://omarchy.org |
| **mise**                 | User-level bootstrap CLI tools  | https://mise.jdx.dev                     |
| **chezmoi**              | Dotfiles management, templating | https://chezmoi.io                       |
| **1Password CLI (`op`)** | Secrets management              | https://developer.1password.com/docs/cli |
| **git**                  | Version control for dotfiles    | -                                        |
