# Dotfiles

Chezmoi-managed dotfiles for AI agent environments. One-command bootstrap on fresh machines.

## Quick start

```bash
curl -fsSL https://raw.githubusercontent.com/BerryBolt/dotfiles/main/install.sh | bash
```

You need a **1Password service account token** — see [1password-setup skill](skills/1password-setup/SKILL.md) to create one.

During setup you'll configure: agent name, email, GitHub handle, vault name, and AI CLI choice (claude / codex / none).

After bootstrap, restart your shell (`exec $SHELL`) and use your AI CLI to run skills from `skills/`.

## What gets installed

### Dotfiles
- `~/.zprofile` — Homebrew setup (macOS)
- `~/.zshrc` — Shell config (mise, starship, zoxide, fzf)
- `~/.gitconfig` — Git config with signing
- `~/.config/mise/config.toml` — CLI tools
- `~/.openclaw/*` — OpenClaw config (if using OpenClaw)

### CLI tools (via mise)
- chezmoi, gh, starship, zoxide, fzf, jq, ripgrep
- 1password-cli
- Language runtimes (node, python, go, etc.) available but commented out - uncomment as needed

### GUI apps + system deps (via Homebrew, macOS only)
- 1password, brave-browser, claude, tailscale
- tmux, ffmpeg, whisper-cpp
- Custom taps (see `home/Brewfile`)

### Restored from 1Password
- SSH key (`~/.ssh/id_ed25519`)

## Post-bootstrap

After SSH key is restored from 1Password, switch to SSH remote:

```bash
git -C ~/.local/share/chezmoi remote set-url origin git@github.com:BerryBolt/dotfiles.git
```

Optional next steps:
- Clone workspace: `git clone git@github.com:BerryBolt/workspace.git ~/workspace`
- Install [OpenClaw](https://openclaw.ai) if you want an alternative to Claude Code / Codex

## Structure

```
home/           # Chezmoi source (dotfiles, scripts, Brewfile)
policies/       # Operations manual for AI agents
skills/         # AI-executable procedures
install.sh      # One-liner bootstrap script
```

## For AI agents

This repo includes:
- **[policies/](policies/)** — Self-serve operations manual (credentials, dependencies, dotfiles, git)
- **[skills/](skills/)** — AI-executable procedures in [agentskills.io](https://agentskills.io) format

These dotfiles are templated for multiple agents. Each agent has separate macOS user + 1Password vault, same repo.

## License

MIT
