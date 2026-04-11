# Dotfiles

Chezmoi-managed bootstrap for Berry Bolt agent environments.

Targets `macOS`, `Linux`, and `WSL2`, following the same baseline assumptions as OpenClaw. The installer entrypoint is `bash`. macOS-only package steps are skipped automatically on other platforms.

## Quick start

```bash
curl -fsSL https://berrybolt.bot/install.sh | bash
```

## Prerequisites

Before running the installer, prepare:

- a **1Password service account token** with access to the vault you will enter during setup
- in that vault, an `SSH Key` item titled `id_ed25519`
- in that vault, an `API Credential` item titled `Telegram Bot - API key` with a `credential` field for the default included OpenClaw config

See [skills/1password-setup/SKILL.md](skills/1password-setup/SKILL.md) for the service account setup flow.

The installer prompts for:
- agent name
- agent email
- GitHub handle
- 1Password vault name
- AI CLI (`claude`, `codex`, or `none`)

## Package sources

- CLI tools are defined in [home/private_dot_config/mise/config.toml](home/private_dot_config/mise/config.toml)
- macOS-specific GUI apps and system packages are defined in [home/Brewfile](home/Brewfile)

## After install

- restart your shell: `exec "$SHELL" -l`
- optional: clone workspace with `git clone git@github.com:BerryBolt/workspace.git ~/workspace`
- optional: install [OpenClaw](https://openclaw.ai)

## Layout

```text
home/           # chezmoi source: dotfiles, scripts, Brewfile
policies/       # operations manual for AI agents
skills/         # AI-executable procedures
install.sh      # bootstrap entrypoint
```

## For AI agents

This repo includes:
- [policies/](policies/) for credentials, dependencies, dotfiles, and git workflows
- [skills/](skills/) in [agentskills.io](https://agentskills.io) format

These dotfiles are templated for multiple agents. Each agent has a separate OS user and 1Password vault, but shares the same repo.

## License

MIT
