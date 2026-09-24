# Dependencies

What the Omarchy workstation supplies and what this repo adds on top.

## Ownership

| Layer | Owner | Examples |
| --- | --- | --- |
| Desktop, shell defaults, system packages | Omarchy / pacman | Bash and its init, Git, OpenSSH, curl, mise, and the shell conveniences Omarchy's init loads |
| User-level bootstrap tools | This repo, via mise | `chezmoi`, 1Password CLI (`op`) |
| User's own mise tools | The user | Entries in `~/.config/mise/config.toml` |
| Agent CLIs and runtimes | Future harness/workspace setup | Out of scope here |

- This repo MUST NOT install system packages. `install.sh` checks for the Omarchy-provided prerequisites (`git`, `ssh`, `ssh-keygen`, `mise`) and stops with an actionable error when one is missing.
- This repo MUST NOT duplicate tools Omarchy already provides, and MUST NOT install shell conveniences or a second shell.
- This repo MUST NOT write `~/.config/mise/config.toml`. Its tools live in the additive manifest `~/.config/mise/conf.d/dotfiles.toml`, which mise loads alongside the user's global config.

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
