# Dotfiles

Chezmoi-managed dotfiles for AI agent environments. Designed for one-command bootstrap on fresh machines.

## Prerequisites

Before bootstrapping, you need:

1. **1Password account** with a vault for this agent
2. **1Password service account token** — see [skills/1password-setup](skills/1password-setup/SKILL.md) for setup instructions

The service account must have access to the agent's vault.

## Quick start

### macOS

```bash
# 1. Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"

# 2. Install mise (entry point)
brew install mise
eval "$(mise activate zsh)"

# 3. Install chezmoi via mise
mise use chezmoi@latest

# 4. Set 1Password token
export OP_SERVICE_ACCOUNT_TOKEN="<your-token>"

# 5. Bootstrap (uses HTTPS to avoid SSH chicken-and-egg)
chezmoi init --apply https://github.com/BerryBolt/dotfiles.git

# 6. Restart shell
exec zsh
```

### Linux (Ubuntu/Debian)

```bash
# 1. Install mise
curl https://mise.run | sh
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
source ~/.bashrc

# 2. Install chezmoi via mise
mise use chezmoi@latest

# 3. Set 1Password token
export OP_SERVICE_ACCOUNT_TOKEN="<your-token>"

# 4. Bootstrap
chezmoi init --apply https://github.com/BerryBolt/dotfiles.git

# 5. Restart shell
exec bash
```

### Prompts

You'll be prompted for:
- Agent name (e.g., `Berry Bolt`)
- Agent email (e.g., `hi@berrybolt.bot`)
- GitHub handle (e.g., `BerryBolt`)
- 1Password vault name
- 1Password service account token
- AI CLI choice (claude-code / codex / none)

### AI-assisted setup

After bootstrap, use the installed AI CLI to run skills:

```bash
# Start AI CLI
claude  # or codex

# AI can read skills/ directory and help with:
# - 1Password troubleshooting
# - Adding new credentials
# - Managing dotfiles
```

Skills are in `skills/` — AI-readable procedures for common tasks.

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

### Install OpenClaw (optional)

These dotfiles work with any AI CLI (Claude Code, Codex, Gemini CLI, etc.). OpenClaw is optional.

```bash
curl -fsSL https://openclaw.ai/install.sh | bash
```

If installed, OpenClaw can use the same skills and policies from this repo.

### Clone workspace/brain repo (optional)

```bash
git clone git@github.com:BerryBolt/workspace.git ~/workspace
```

### Switch remote to SSH (optional)

After SSH key is restored, switch chezmoi remote from HTTPS to SSH:

```bash
git -C ~/.local/share/chezmoi remote set-url origin git@github.com:BerryBolt/dotfiles.git
```

## Repository structure

```
.
├── README.md
├── .chezmoiroot              # Points to home/
├── home/                     # Chezmoi source root
│   ├── .chezmoi.toml.tmpl    # Init prompts
│   ├── .chezmoiscripts/      # run_once scripts
│   │   └── darwin/           # macOS-specific
│   ├── Brewfile              # GUI apps, system deps (macOS)
│   ├── dot_zshrc
│   ├── dot_zprofile
│   ├── dot_gitconfig.tmpl
│   ├── private_dot_config/   # mise config, etc.
│   └── private_dot_openclaw/ # OpenClaw config
├── policies/                 # Self-serve operations manual
│   ├── README.md             # SSOT, index
│   ├── credentials.md        # 1Password
│   ├── dependencies.md       # mise, Homebrew
│   ├── dotfiles.md           # chezmoi
│   └── git.md                # Version control
└── skills/                   # AI-executable procedures
    └── 1password-setup/      # Service account setup
```

## Template variables

| Variable | Description |
|----------|-------------|
| `{{ .agent_name }}` | Agent display name |
| `{{ .agent_email }}` | Agent email |
| `{{ .agent_handle_github }}` | GitHub username |
| `{{ .op_vault }}` | 1Password vault name |
| `{{ .op_service_account_token }}` | 1Password service account token |

## Policies

See `policies/README.md` for the policy index:
- [dependencies.md](policies/dependencies.md) — Package management (mise, Homebrew)
- [credentials.md](policies/credentials.md) — 1Password operations
- [dotfiles.md](policies/dotfiles.md) — chezmoi operations
- [git.md](policies/git.md) — Version control practices

## Multi-agent support

These dotfiles are templated for multiple agents. Each agent (Berry Bolt, Pandi Volt, etc.) has:
- Separate macOS user account
- Separate 1Password vault
- Same dotfiles repo, different template values

## License

Private repository. Not for distribution.
