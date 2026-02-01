# Dependencies

Package management for CLI tools, runtimes, and system dependencies.

## Package manager hierarchy

```
mise (primary)     →  CLI tools, language runtimes
Homebrew (macOS)   →  GUI apps, system dependencies, mise itself
apt/dnf (Linux)    →  GUI apps, system dependencies, mise itself
```

## What goes where (strict)

| Type | Manager | Config file |
|------|---------|-------------|
| CLI tools (binary releases) | mise | `~/.config/mise/config.toml` |
| Language runtimes | mise | `~/.config/mise/config.toml` |
| GUI apps | Homebrew/apt | `Brewfile` (macOS) |
| System dependencies (compilation needed) | Homebrew/apt | `Brewfile` (macOS) |
| Custom taps | Homebrew | `Brewfile` (macOS) |

## Why mise first

- Cross-platform: same config works on macOS and Linux
- User-space: no sudo required
- Version pinning: reproducible environments
- Fast: binary downloads, no compilation

## Adding a new tool

1. **Check mise first:** `mise registry | grep -i "<tool>"`
2. **If in mise:** `mise use <tool>@latest` (updates config.toml)
3. **If NOT in mise:** add to `Brewfile` with comment explaining why
4. **Commit the config file**

MUST prefer mise over Homebrew when both are available.

## mise operations

```bash
# Install all tools from config
mise install

# Add a tool
mise use <tool>@<version>

# Update all tools
mise upgrade

# List installed tools
mise list

# Check what would be installed
mise list --missing
```

## Brewfile operations (macOS)

```bash
# Install all from Brewfile
brew bundle --file=~/.local/share/chezmoi/home/Brewfile

# Add what's currently installed to Brewfile
brew bundle dump --file=~/.local/share/chezmoi/home/Brewfile --force

# Check what would be installed
brew bundle check --file=~/.local/share/chezmoi/home/Brewfile
```

## Bootstrap entry points

| OS | Install mise | Then |
|----|--------------|------|
| macOS | `brew install mise` | `mise install && chezmoi apply` |
| Ubuntu | `apt install mise` or curl | `mise install && chezmoi apply` |
| Fedora | `dnf install mise` | `mise install && chezmoi apply` |

After mise is installed, the rest is identical across platforms.
