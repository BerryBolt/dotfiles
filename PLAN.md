# Dotfiles + Bootstrap Plan

**Owner:** Raz + Berry Bolt
**Status:** Phase 2.8 complete, ready for Phase 3 (bootstrap testing)
**Goal:** One-command bootstrap for Berry (or any AI bot) on a fresh machine, with portable dotfiles and data backup.

---

## North star vision

Create an **Omakub-like setup for agentic environments** — opinionated, open-source, with:
- Security defaults for AI agents
- Tooling (OpenClaw, Claude Code, etc.)
- AI-assisted bootstrap (fuzzy/interactive setup via skills)
- Dotfiles component (this plan)

This is the foundation. The broader "agentic omakub" is future scope.

Reference: [Omakub](https://omakub.org) / [Omarchy](https://github.com/basecamp/omarchy)

---

## Architectural split: Dotfiles vs Workspace

### Dotfiles/Infra repo (this repo)
**Purpose:** Environment setup, operational policies, bootstrap

Contains:
- chezmoi templates (shell, git, OpenClaw config)
- **Operational policies** — credentials, security, self-setup (HOW the agent operates)
- **Bootstrap skills** — AI-assisted setup for fuzzy/interactive tasks (OAuth, service registration, etc.)
- Brewfile, scripts, run_once hooks

### Workspace/Brain repo (agent's memory)
**Purpose:** Identity, memory, behavioral policies

Contains:
- Identity (SOUL.md, IDENTITY.md, USER.md)
- Memory (daily notes, MEMORY.md)
- **Behavioral policies** — responsible autonomy, communication style (WHO the agent is)
- Skills for runtime tasks (not bootstrap)

### Why this split?
- Credentials policy is about infrastructure, not persona — belongs in dotfiles
- Bootstrap needs AI for fuzzy tasks (chezmoi handles deterministic, AI handles the rest)
- Workspace should be pure "brain" — portable across different infrastructure setups
- A 14-year-old can run the bootstrap; the AI handles complexity

### Repo structure (target)

```
dotfiles/
├── .chezmoiroot              # contains "home"
├── README.md
├── policies/
│   └── credentials-policy.md  # moved from workspace
├── scripts/
└── home/                      # chezmoi source root
    ├── .chezmoi.toml.tmpl
    ├── .chezmoiscripts/
    │   ├── darwin/            # macOS-specific
    │   └── linux/             # Linux-specific
    ├── dot_zshrc
    ├── dot_gitconfig.tmpl
    ├── private_dot_config/
    └── private_dot_openclaw/
```

---

## First principles: Is chezmoi the right approach?

### Alternatives considered

| Approach | Pros | Cons |
|----------|------|------|
| **chezmoi** | Mature, templates, 1Password integration, cross-platform | Another tool to learn |
| **Pure shell scripts** (Omakub-style) | Simple, readable, no dependencies | No templating, manual state management |
| **Nix/Home Manager** | Fully declarative, reproducible | Steep learning curve, different paradigm |
| **Ansible** | Can manage everything, idempotent | Heavier, more suited for server fleets |

### Decision: Hybrid approach

**chezmoi for dotfiles/configs** + **simple wrapper script for bootstrap**

Why:
- chezmoi has built-in 1Password integration (critical for secrets)
- Template system handles multi-bot variables cleanly
- Omakub itself is Linux/Gnome-specific; we need macOS + Linux
- Shell scripts alone can't easily template configs with secrets

The wrapper script handles: Homebrew/apt install, chezmoi install, 1P signin.
chezmoi handles: dotfiles, configs, templates, secrets injection.

---

## Understanding gathered

### Current environment

- **Machine:** macOS VM (UTM) on Mac host
- **User:** `berrybolt` (AI-dedicated user for Berry Bolt)
- **Shell:** zsh (but mise not activated yet)
- **1Password:** Source of truth for all credentials (dedicated account for Berry)
- **OpenClaw:** `~/.openclaw` — runtime data, config, sessions
- **Workspace/Brain:** `~/.openclaw/workspace` (default) or `~/workspace` (Berry's custom) — memory, identity, policies

### What needs to be managed

| Category | Location | Strategy |
|----------|----------|----------|
| Shell config | `~/.zshrc`, `~/.zprofile` | chezmoi template |
| Git config | `~/.gitconfig` | chezmoi template (no secrets) |
| mise config | `~/.config/mise/config.toml` | chezmoi |
| OpenClaw config | `~/.openclaw/openclaw.json` | chezmoi template + 1P injection |
| OpenClaw .env | `~/.openclaw/.env` | chezmoi template + 1P injection |
| SSH keys | `~/.ssh/` | 1Password (restore during bootstrap) |
| Homebrew packages | Brewfile | chezmoi + brew bundle |
| Brain/workspace | `~/.openclaw/workspace` (default) | Separate git repo (Phase 2 — after validation) |

### What NOT to manage (ephemeral/recreated)

- `~/.openclaw/browser/` — Chromium profile (huge, sensitive)
- `~/.openclaw/agents/` — Runtime session state
- `~/.openclaw/memory/` — SQLite session data (backup separately)
- `~/.openclaw/logs/` — Ephemeral
- `~/.openclaw/media/` — Generated files
- `~/.openclaw/identity/` — Device keys (regenerated per machine)
- `~/.openclaw/devices/` — Paired device tokens
- `~/.openclaw/credentials/` — Pairing state
- `~/.openclaw/telegram/` — Offset state
- `.claude*`, `.clawdbot/` — Claude Code state (regenerated)

---

## Architecture

### Two repos

1. **Brain repo** (exists): `~/workspace` — Berry's memory, identity, policies, runbooks
2. **Dotfiles repo** (new): `github.com/BerryBolt/dotfiles` — chezmoi-managed config + bootstrap

### Template system (multi-bot support)

The dotfiles repo will use chezmoi templates with variables, making it reusable for other AI bots:

```toml
# ~/.config/chezmoi/chezmoi.toml (per-machine, not committed)
[data]
  agent_name = "Berry Bolt"
  agent_email = "hi@berrybolt.bot"
  agent_handle_github = "BerryBolt"
  op_vault = "Berry Bolt"
```

Note: `brain_repo` / workspace location is configured in OpenClaw (`~/.openclaw/openclaw.json`), not chezmoi.

Another bot (e.g., Pandi Volt) would have different values but use the same dotfiles repo structure.

### Multi-bot clarification

"Multi-bot" here means **separate Mac users**, each with their own OpenClaw install:
- `berrybolt` (Berry Bolt) — separate Mac user, separate OpenClaw, separate 1P account
- `pandivolt` (Pandi Volt) — separate Mac user, separate OpenClaw, separate 1P account

This is NOT about multiple agents within one OpenClaw setup (that's a different feature to explore later).

The dotfiles repo is templated so it can bootstrap either user with their own variables.

| Bot | Mac user | GitHub | Email | 1P Vault |
|-----|----------|--------|-------|----------|
| Berry Bolt | `berrybolt` | `@BerryBolt` | `hi@berrybolt.bot` | `Berry Bolt` |
| Pandi Volt | `pandivolt` | `@PandiVolt` | TBD | TBD |

---

## Bootstrap flow (target)

Fresh macOS VM:

```bash
# 1. Install Homebrew (if not present)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv zsh)"

# 2. Install chezmoi + 1password-cli
brew install chezmoi 1password-cli

# 3. Sign in to 1Password
op account add --address my.1password.com
eval $(op signin)

# 4. Initialize chezmoi (prompts for template variables)
chezmoi init --apply BerryBolt/dotfiles

# 5. Done! Shell reload, then:
#    - SSH keys restored from 1P
#    - Homebrew packages installed
#    - Brain repo cloned
#    - OpenClaw config templated
#    - Shell (zsh) configured with mise/starship/zoxide
```

---

## Secrets strategy

**Rule: No secrets in git. Ever.**

### 1Password injection at apply-time

chezmoi templates will reference 1Password items:

```
# In template
{{ onepasswordRead "op://Berry Bolt/OpenClaw Gateway Token/password" }}
```

Required 1P items:
- `OpenClaw Gateway Token` — `gateway.auth.token`
- `Telegram Bot Token` — `channels.telegram.botToken`
- `SSH Key — Berry Bolt` — Private key (Document item)
- `OP_SERVICE_ACCOUNT_TOKEN` — For non-interactive bootstrap

### SSH key restoration

```bash
# run_once_before script
op document get "SSH Key — Berry Bolt" --out-file ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
ssh-keygen -y -f ~/.ssh/id_ed25519 > ~/.ssh/id_ed25519.pub
```

---

## Homebrew management

### Brewfile (committed to dotfiles repo)

```ruby
# Taps
tap "homebrew/bundle"

# Core tools
brew "mise"
brew "gh"
brew "tmux"
brew "cloudflared"

# AI/LLM tools
brew "claude"  # if available, else cask
brew "gemini-cli"

# Media
brew "ffmpeg"
brew "whisper-cpp"

# Casks
cask "1password"
cask "1password-cli"
cask "brave-browser"
cask "tailscale-app"
```

### Bootstrap script

```bash
# run_once_before_install-packages.sh.tmpl
#!/bin/bash
brew bundle --file={{ .chezmoi.sourceDir }}/Brewfile
```

---

## Shell configuration

### ~/.zshrc (template)

```bash
# Homebrew
eval "$(/opt/homebrew/bin/brew shellenv zsh)"

# mise (version manager)
if command -v mise &> /dev/null; then
  eval "$(mise activate zsh)"
fi

# starship prompt (optional)
if command -v starship &> /dev/null; then
  eval "$(starship init zsh)"
fi

# zoxide (smarter cd)
if command -v zoxide &> /dev/null; then
  eval "$(zoxide init zsh)"
fi

# fzf
if command -v fzf &> /dev/null; then
  source <(fzf --zsh)
fi

# Aliases
alias ll="ls -la"
alias g="git"
alias brain="cd ~/workspace"
```

---

## OpenClaw data backup (north star)

The lost `.clawdbot` data during migration is a real concern. Strategy:

### What to back up

| Data | Location | Backup method |
|------|----------|---------------|
| Session memory | `~/.openclaw/memory/main.sqlite` | Periodic copy to cloud storage / backup repo |
| Agent state | `~/.openclaw/agents/` | Periodic snapshot |
| Cron jobs | `~/.openclaw/cron/jobs.json` | chezmoi (if we decide to source-control) |

### Backup options

1. **Git repo (simplest)** — Periodic commit of critical files to a private backup repo
2. **Restic/rclone to cloud** — Automated, encrypted backups to B2/S3
3. **Time Machine** — macOS native (but not portable to Linux)
4. **OpenClaw native export** — If/when available

### Recommendation: Git-based backup (simplest)

Start with a **private git repo** for critical OpenClaw data:
- `~/.openclaw/memory/main.sqlite` — Session history
- `~/.openclaw/cron/jobs.json` — Scheduled tasks
- `~/.openclaw/agents/*/agent/` — Agent config (not session state)

Why git:
- Already familiar tooling
- Version history built-in
- Works everywhere
- Can automate with cron/launchd + simple script
- Upgrade to restic later if needed

```bash
# Simple backup script (run periodically)
cd ~/.openclaw-backup
cp ~/.openclaw/memory/main.sqlite .
cp ~/.openclaw/cron/jobs.json .
git add -A && git commit -m "Backup $(date +%Y-%m-%d)" && git push
```

---

## Task checklist

### Phase 1: Foundation (current focus)

#### 1.1 Initialize chezmoi
- [x] **1.1.1** Verify chezmoi is installed: `chezmoi --version`
- [x] **1.1.2** Initialize chezmoi locally: `chezmoi init`
  - Creates `~/.local/share/chezmoi/` (source directory)
- [x] **1.1.3** Verify source directory exists: `ls -la ~/.local/share/chezmoi/`

#### 1.2 Create GitHub repo
- [x] **1.2.1** Create private repo on GitHub: `gh repo create BerryBolt/dotfiles --private`
- [x] **1.2.2** Link chezmoi to remote: `git -C ~/.local/share/chezmoi remote add origin git@github.com:BerryBolt/dotfiles.git`
- [x] **1.2.3** Verify remote: `git -C ~/.local/share/chezmoi remote -v`

#### 1.3 Add shell config
- [x] **1.3.1** Add current `.zprofile` to chezmoi: `chezmoi add ~/.zprofile` + commit
- [x] **1.3.2** Edit `.zprofile` in chezmoi source to ensure Homebrew setup (already correct)
- [x] **1.3.3** Add current `.zshrc` to chezmoi: `chezmoi add ~/.zshrc` + commit
- [x] **1.3.4** Edit `.zshrc` in chezmoi source to add mise/starship/zoxide/fzf activation + commit
- [x] **1.3.5** Review changes: `chezmoi diff`
- [x] **1.3.6** Apply changes: `chezmoi apply`
- [x] **1.3.7** Verify shell works: `source ~/.zshrc && mise --version`

#### 1.4 Add git config
- [x] **1.4.1** Review current `.gitconfig`: `cat ~/.gitconfig`
- [x] **1.4.2** Add to chezmoi as template: `chezmoi add --template ~/.gitconfig`
- [x] **1.4.3** Edit template to use chezmoi variables for name/email + commit
- [x] **1.4.4** Review: `chezmoi diff` (no diff — values already match)
- [x] **1.4.5** Apply: `chezmoi apply` (no changes needed for gitconfig)

#### 1.5 Add mise config
- [x] **1.5.1** Review current mise config: `cat ~/.config/mise/config.toml`
- [x] **1.5.2** Add to chezmoi: `chezmoi add ~/.config/mise/config.toml` + commit
- [x] **1.5.3** Review: `chezmoi diff` (no diff — file unchanged)

#### 1.6 Create Brewfile
- [x] **1.6.1** Generate Brewfile from current packages: `brew bundle dump --file=~/.local/share/chezmoi/Brewfile`
- [x] **1.6.2** Review Brewfile
- [x] **1.6.3** Add starship, zoxide, fzf + run `brew bundle` + commit

#### 1.7 Configure chezmoi template variables
- [x] **1.7.1** Create chezmoi config: `chezmoi edit-config`
- [x] **1.7.2** Add `[data]` section with agent variables
- [x] **1.7.3** Verify template rendering: `chezmoi execute-template '{{ .agent_name }}'`

#### 1.8 Test locally
- [x] **1.8.1** Full diff check: `chezmoi diff`
- [x] **1.8.2** Apply all: `chezmoi apply`
- [x] **1.8.3** Verify shell: mise/starship/zoxide work
- [x] **1.8.4** Verify git: `git config user.name && git config user.email`

#### 1.9 Push to GitHub
- [x] **1.9.1** All commits made atomically throughout Phase 1
- [x] **1.9.2** Push: `git push -u origin main`
- [x] **1.9.3** Verify on GitHub: `gh repo view BerryBolt/dotfiles --web`

**Phase 1 complete!** (2026-02-01)

---

### Phase 2: OpenClaw config

#### 2.1 Create chezmoi init template (prompts)
- [x] **2.1.1** Create `.chezmoi.toml.tmpl` in source dir
- [x] **2.1.2** Add prompts for: agent_name, agent_email, op_service_account_token, op_vault
- [x] **2.1.3** Test: skipped (need fresh env) — will test in Phase 3
- [x] **2.1.4** Commit

#### 2.2 Template .env
- [x] **2.2.1** Add `.env` to chezmoi as template: `chezmoi add --template ~/.openclaw/.env`
- [x] **2.2.2** Edit template: use `{{ .op_service_account_token }}` and `{{ .op_vault }}`
- [x] **2.2.3** Test: `chezmoi cat ~/.openclaw/.env`
- [x] **2.2.4** Commit

#### 2.3 Template openclaw.json
- [x] **2.3.1** Add to chezmoi as template: `chezmoi add --template ~/.openclaw/openclaw.json`
- [x] **2.3.2** Edit template: workspace path → `{{ .chezmoi.homeDir }}`, Telegram token → 1P lookup, Brave apiKey → empty
- [x] **2.3.3** Test: `chezmoi cat ~/.openclaw/openclaw.json`
- [x] **2.3.4** Commit

#### 2.4 SSH key restoration
- [x] **2.4.1** Create `run_once_before_01-restore-ssh-key.sh.tmpl`
- [x] **2.4.2** Script: fetch SSH key from 1P, set permissions, skip if exists
- [x] **2.4.3** Test template rendering: `chezmoi execute-template`
- [x] **2.4.4** Commit

#### 2.5 Push and test
- [x] **2.5.1** Push all Phase 2 changes
- [x] **2.5.2** Test on current machine: `chezmoi apply`
- [ ] **2.5.3** Document any manual steps needed (defer to Phase 3)

### Phase 2.6: Repo reorganization
- [x] **2.6.1** Create `home/` directory structure
- [x] **2.6.2** Add `.chezmoiroot` with `home`
- [x] **2.6.3** Move dotfiles into `home/`
- [x] **2.6.4** Create `home/.chezmoiscripts/darwin/` and move run_once scripts
- [ ] **2.6.5** Add README.md at repo root (deferred)
- [x] **2.6.6** Move credentials-policy.md from workspace to `policies/`
- [x] **2.6.7** Commit and push

**Phase 2.6 complete!** (2026-02-01)

### Phase 2.7: Policy rewrite (ops manual)
- [x] **2.7.1** Rewrite credentials-policy.md as self-serve ops manual
- [x] **2.7.2** Focus: chezmoi operations, 1P operations, git practices, naming conventions
- [x] **2.7.3** Remove guardrails/escalation language (agent is autonomous)
- [x] **2.7.4** Add placeholder for `1password-setup` skill
- [x] **2.7.5** Commit and push

**Phase 2.7 complete!** (2026-02-01)

### Phase 2.8: mise as primary package manager + policy split
- [x] **2.8.1** Refactor: mise for CLI tools, Homebrew for GUI apps + system deps only
- [x] **2.8.2** Expand mise config with CLI tools (chezmoi, gh, starship, zoxide, fzf, etc.)
- [x] **2.8.3** Trim Brewfile to GUI apps only (1password, brave, etc.)
- [x] **2.8.4** Split policy into multiple docs (README, dependencies, credentials, dotfiles, git)
- [x] **2.8.5** Update README with new bootstrap flow (macOS + Linux)
- [x] **2.8.6** Add run_once scripts (install-packages, install-openclaw)
- [x] **2.8.7** Commit and push

**Phase 2.8 complete!** (2026-02-01)

### Phase 3: Bootstrap automation
- [ ] Create `run_once_before` scripts for Homebrew
- [ ] Create `run_once_after` scripts for OpenClaw install (`curl | bash`)
- [ ] Document bootstrap procedure
- [ ] Test end-to-end on fresh VM

### Phase 3.5: AI-assisted bootstrap (future)
- [ ] Design bootstrap skills for fuzzy/interactive tasks
- [ ] OAuth flows, service registration, pairing
- [ ] AI reads credentials-policy and follows it
- [ ] Skills can be run via OpenClaw or direct provider CLI

### Phase 4: Multi-bot template (later)
- [ ] Extract all bot-specific values to chezmoi data
- [ ] Document template variables
- [ ] Test with Pandi Volt user

### Phase 5: Data backup (later)
- [ ] Set up git-based backup for OpenClaw data
- [ ] Create backup schedule (cron/launchd)
- [ ] Document restore procedure

### Phase 6: Linux compatibility (later)
- [ ] Add OS detection to templates
- [ ] Handle Homebrew vs apt
- [ ] Test on Ubuntu VM/VPS

---

## Decisions (resolved)

1. **Repo hosting:** GitHub under `@BerryBolt`, **private** (Berry's personal dotfiles; open-source template version later)
2. **Cron jobs:** Source-control `jobs.json` — lost them before, want them back
3. **Backup:** Simplest solution — git repo
4. **Linux target:** Ubuntu (possibly on Omarchy later)
5. **OpenClaw install:** Bootstrap uses `curl -fsSL https://openclaw.ai/install.sh | bash`
6. **Second bot:** Pandi Volt (`pandivolt`, `@PandiVolt`)
7. **Workspace location:** Use OpenClaw default (`~/.openclaw/workspace`) for validation; custom location (`~/workspace`) is Berry-specific
8. **Shell tools:** Start with mise, include starship/zoxide/fzf (full toolset)
9. **Brain/workspace template:** Separate effort — comes from OpenClaw setup with customizations

---

## Current Homebrew inventory

### Formulae
```
bird, brotli, c-ares, ca-certificates, cloudflared, dav1d, ffmpeg,
gemini-cli, gh, gifgrep, go, gogcli, goplaces, icu4c@78, lame,
libevent, libnghttp2, libnghttp3, libngtcp2, libuv, libvpx, lz4,
memo, mise, mole, mpdecimal, ncurses, node, node@22, obsidian-cli,
openssl@3, opus, peekaboo, pnpm, python@3.13, readline, remindctl,
sdl2, simdjson, simdutf, sqlite, summarize, svt-av1, tmux, usage,
utf8proc, uv, uvwasi, whisper-cpp, x264, x265, xz, zstd
```

### Casks
```
1password, 1password-cli, antigravity, brave-browser, claude, tailscale-app
```

---

## References

- Existing runbook (Berry's brain): `~/workspace/runbooks/chezmoi-clawdbot-portable.md`
- chezmoi docs: https://chezmoi.io/
- OpenClaw docs: https://docs.openclaw.ai/
- Omakub: https://omakub.org / https://github.com/basecamp/omakub
- Omarchy: https://github.com/basecamp/omarchy

---

## Validation approach

**Step 1: Fresh VM test (default OpenClaw workspace)**
1. Create new macOS VM (or new user on existing VM)
2. Run bootstrap script
3. Verify: shell works, mise activated, tools installed, OpenClaw running
4. Uses default `~/.openclaw/workspace` — no custom brain yet

**Step 2: Custom brain integration**
1. After Step 1 works, add brain repo clone to bootstrap
2. Configure OpenClaw to use `~/workspace` (or keep default)
3. Test with Berry's actual workspace repo

---

## Next action

**Start with task 1.1.1**: Verify chezmoi is installed

```bash
chezmoi --version
```

Then proceed through the checklist sequentially. You execute each command, I'll guide and explain.
