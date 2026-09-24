# Dependencies

What Omarchy supplies, and how this repo declares and installs everything else the workstation needs.

## Ownership

| Layer | Source | Examples |
| --- | --- | --- |
| Omarchy base | Omarchy installation | Bash and its init, Git, OpenSSH, curl, mise, desktop and shell defaults |
| Omarchy on-demand tools | Omarchy's `~/.local/bin` launchers | `gh`, codex, claude, copilot, and others; installed through mise on first use |
| User-level tools Omarchy lacks | This repo: `~/.config/mise/conf.d/dotfiles.toml` | `chezmoi`, 1Password CLI (`op`) |
| System packages | This repo: `run_once_after_40-install-system-packages.sh`, through Omarchy's package commands | Brave (AUR, with `omarchy-install-browser`) |

- Everything the workstation needs MUST be declared in this repo and installed by apply or `install.sh`; nothing is installed by hand. The agent has full administrative rights in its VM, and setup grants its account passwordless sudo (ARCHITECTURE.md, script 20), so apply script 40 installs system packages unattended.
- Install system packages with Omarchy's commands where one exists (`omarchy-install-browser`, `omarchy-pkg-add` for Arch repositories, `omarchy-pkg-aur-add` for the AUR). They skip what is already installed and apply Omarchy's settings for the package.
- Go default first: if Omarchy provides a tool, including through an on-demand launcher, use Omarchy's route and do not declare the tool here.
- For tools Omarchy lacks, prefer user-level installs through mise; use pacman for what needs the system package manager.
- MUST NOT duplicate a tool Omarchy already provides.
- 1Password: the repo installs only the CLI, from the manifest. Omarchy's `omarchy-install-service-1password` adds the desktop app and browser extension, which a service account cannot sign in to, so it is not used (see the [access model](credentials.md#access-model)).
- SHOULD NOT write `~/.config/mise/config.toml`: Omarchy's on-demand launchers record their tools there on first use. The repo's tools live in the additive manifest `~/.config/mise/conf.d/dotfiles.toml`, which mise loads alongside it.
- `install.sh` checks for the Omarchy-provided prerequisites (`git`, `ssh`, `ssh-keygen`, `mise`) and stops with an actionable error when one is missing.

## User-level tools manifest

The manifest source is [home/dot_config/mise/conf.d/dotfiles.toml](../home/dot_config/mise/conf.d/dotfiles.toml). It is the single list of mise tools this repo installs:

- `run_once_after_10-install-mise-tools.sh.tmpl` reads the tool names from the manifest at render time, installs exactly those, and reruns when the manifest changes.
- `BOOTSTRAP_TOOLS` in `install.sh` lists only the tools the first apply needs before any script runs: `chezmoi`, and `1password-cli` because templates call `op`. Each of them must also be in the manifest.

To add a tool the workstation needs, add it to the manifest. Touch `BOOTSTRAP_TOOLS` only if templates need the tool during the first render.

## mise operations

```bash
mise ls                 # installed tools and the config file that declares each
mise config ls          # active config files, including conf.d/dotfiles.toml
mise install chezmoi 1password-cli   # reinstall the bootstrap tools
mise upgrade chezmoi 1password-cli   # upgrade within the manifest's versions
```

Package managers own reinstalling missing tool binaries. Apply scripts do not attempt general repair.
