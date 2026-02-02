# Dotfiles

chezmoi operations for managing dotfiles.

## Source directory

```
~/.local/share/chezmoi/          # chezmoi source (this repo)
├── .chezmoiroot                 # points to home/
├── home/                        # actual dotfiles
│   ├── .chezmoi.toml.tmpl       # init prompts
│   ├── .chezmoiscripts/         # run_once scripts
│   ├── dot_zshrc
│   └── private_dot_*/           # private files
├── policies/                    # reference docs
└── skills/                      # AI-executable procedures (agentskills.io format)
```

## Common commands

```bash
# View pending changes
chezmoi diff

# Apply changes
chezmoi apply

# Add a file (makes it managed)
chezmoi add ~/.some-config

# Add as template
chezmoi add --template ~/.some-config

# Edit a managed file
chezmoi edit ~/.some-config

# View what chezmoi would generate
chezmoi cat ~/.some-config

# Re-init (re-run prompts)
chezmoi init
```

## Template variables

Available in `.tmpl` files:

| Variable | Description |
|----------|-------------|
| `{{ .agent_name }}` | Agent display name |
| `{{ .agent_email }}` | Agent email |
| `{{ .agent_handle_github }}` | GitHub username |
| `{{ .op_vault }}` | 1Password vault name |
| `{{ .op_service_account_token }}` | 1Password service account token |
| `{{ .chezmoi.homeDir }}` | Home directory path |
| `{{ .chezmoi.os }}` | Operating system |

## 1Password in templates

```
{{ onepasswordRead "op://<vault>/<item>/<field>" }}
{{ onepasswordRead "op://Berry Bolt/Telegram Bot - API key/credential" | quote }}
```

## Adding a new dotfile

1. Create or edit the file in your home directory
2. Add to chezmoi: `chezmoi add ~/.newfile`
3. If it needs templating: `chezmoi add --template ~/.newfile`
4. Edit template if needed: `chezmoi edit ~/.newfile`
5. Verify: `chezmoi diff`
6. Commit: see [git.md](git.md)

## run_once scripts

Location: `home/.chezmoiscripts/<os>/`

Naming: `run_once_before_<order>-<name>.sh.tmpl`

Example: `run_once_before_01-restore-ssh-key.sh.tmpl`

Scripts run once per machine (tracked by checksum).

## After modifying a managed file

If you edit a file that chezmoi manages (e.g., `~/.zshrc`):

1. Check diff: `chezmoi diff`
2. If changes should persist, update source: `chezmoi add ~/.zshrc`
3. Commit the change
4. Push
