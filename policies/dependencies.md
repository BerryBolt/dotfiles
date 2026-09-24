# Dependencies

What Omarchy supplies, and how this repo declares and installs everything else the workstation needs.

## Ownership

| Layer | Source | Examples |
| --- | --- | --- |
| Omarchy base | Omarchy installation | Bash and its init, Git, OpenSSH, curl, mise, desktop and shell defaults |
| User-level tools | This repo: `~/.config/mise/conf.d/dotfiles.toml` | `chezmoi`, 1Password CLI (`op`) |
| System packages | This repo, through pacman (not implemented yet) | Packages the workstation needs beyond Omarchy's base |
| Omarchy on-demand installs | Omarchy's `~/.local/bin` launchers | They run `mise use -g <tool>`, which writes `~/.config/mise/config.toml` |

- Everything the workstation needs MUST be declared in this repo and installed by apply or `install.sh`; nothing is installed by hand. The agent has full administrative rights in its VM, so system packages are in scope; declare them and install them with pacman when that increment lands.
- Prefer user-level installs through mise when mise provides the tool; use pacman for what needs the system package manager.
- MUST NOT duplicate a tool Omarchy already provides.
- SHOULD NOT write `~/.config/mise/config.toml`: Omarchy's on-demand launchers write it. The repo's tools live in the additive manifest `~/.config/mise/conf.d/dotfiles.toml`, which mise loads alongside it and which makes the matching launcher unnecessary.
- `install.sh` checks for the Omarchy-provided prerequisites (`git`, `ssh`, `ssh-keygen`, `mise`) and stops with an actionable error when one is missing.

## Bootstrap tools manifest

The manifest source is [home/dot_config/mise/conf.d/dotfiles.toml](../home/dot_config/mise/conf.d/dotfiles.toml). Three places must agree:

1. The manifest itself.
2. `BOOTSTRAP_TOOLS` in `install.sh`, which installs the tools before the first apply (chezmoi and `op` are needed to render templates).
3. `run_once_after_10-install-mise-tools.sh.tmpl`, which installs only these tools and reruns when the manifest hash changes.

Add a tool only when the retained bootstrap uses it. Update all three places in the same commit.

## mise operations

```bash
mise ls                 # installed tools and the config file that declares each
mise config ls          # active config files, including conf.d/dotfiles.toml
mise install chezmoi 1password-cli   # reinstall the bootstrap tools
mise upgrade chezmoi 1password-cli   # upgrade within the manifest's versions
```

Package managers own reinstalling missing tool binaries. Apply scripts do not attempt general repair.
