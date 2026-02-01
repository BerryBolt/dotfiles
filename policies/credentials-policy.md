# Environment management policy

Self-serve operations manual for managing dotfiles, credentials, and environment configuration.

## Normative language (RFC 2119/8174)

- **MUST:** Absolute requirement.
- **MUST NOT:** Absolute prohibition.
- **SHOULD:** Strong recommendation; deviate only with a valid, documented reason.
- **SHOULD NOT:** Strong discouragement; deviate only with a valid, documented reason.
- **MAY:** Permission; allowed but not required.

---

## Tools

| Tool | Purpose | Docs |
|------|---------|------|
| **chezmoi** | Dotfiles management, templating | https://chezmoi.io |
| **1Password CLI (`op`)** | Secrets management | https://developer.1password.com/docs/cli |
| **git** | Version control for dotfiles | - |

---

## 1Password operations

### Environment setup

Required environment variables (set before any `op` commands):
- `OP_SERVICE_ACCOUNT_TOKEN` — service account token (MUST NOT log or print)
- `OP_VAULT` — default vault name

### Validate access

Before using 1Password, MUST validate:

```bash
op whoami
op vault list
```

---

## 1Password invariants (strict)

### Categories (mandatory)

| Use case | Category | CLI flag |
|----------|----------|----------|
| Website/service login | `Login` | `--category="Login"` |
| API key or token | `API Credential` | `--category="API Credential"` |
| SSH key | `SSH Key` | `--category="SSH Key"` |
| Credential file (JSON/PEM) | `Document` | `--category="Document"` |

MUST use the correct category. MUST NOT use generic categories like `Password` or `Secure Note` for credentials.

### Naming conventions (mandatory)

| Type | Pattern | Examples |
|------|---------|----------|
| Login | `<Service>` | `GitHub`, `Brave`, `Notion` |
| API key | `<Service> - API key` | `Brave Search - API key`, `Firecrawl - API key` |
| Credential file | `<Service> - Credential File` | `Google Cloud - Credential File` |
| SSH key | `<key filename>` | `id_ed25519` |

Rules:
- MUST use regular hyphen (` - `), MUST NOT use em-dash (`—`)
- MUST NOT include "Login" suffix in login item titles
- MUST NOT include "API key" in login items (separate item)
- Service name MUST match official name (e.g., `GitHub` not `Github` or `github`)

### Item structure (mandatory)

| Item type | Required fields | Optional fields |
|-----------|-----------------|-----------------|
| Login | username, password | website, 2FA (totp), recovery codes |
| API Credential | credential | notes (linked login) |
| SSH Key | private_key | - |
| Document | file attachment | notes (linked login) |

### Linking rules

- API key items MUST include note: `Linked login: <Login title> (item_id: <id>)`
- Credential files MUST include note: `Linked login: <Login title> (item_id: <id>)`
- MUST NOT duplicate the secret value in both linked items

### No duplicates

- MUST NOT create multiple items for the same service/credential
- Before creating: MUST search existing items (see workflow below)

---

## 1Password workflows (strict order)

### Before ANY create operation

```bash
# 1. MUST search first
op item list --vault="$OP_VAULT" --format=json | jq -r '.[].title' | grep -i "<service>"

# 2. If found → STOP. Use existing item or update it.
# 3. If not found → proceed to create
```

### Create workflow

```bash
# 1. Search (see above) - MUST do this first
# 2. Create with correct category and naming
op item create --category="<Category>" \
  --title="<Title per naming convention>" \
  --vault="$OP_VAULT" \
  <fields>

# 3. MUST validate immediately after
op item get "<Title>" --vault="$OP_VAULT" --format=json

# 4. MUST verify: title, category, and fields match expected values
```

### Web login workflow (strict order)

When signing up for a new web service:

```
1. Search 1P for existing login → if exists, use it
2. Create Login item in 1P FIRST (with planned username/email)
3. Validate item exists in 1P
4. THEN proceed with web signup
5. Update 1P item with actual password after signup
6. Update with 2FA/recovery codes if enabled
7. Validate final item state
```

MUST NOT proceed to web signup before creating 1P item. This prevents lost credentials.

### Update workflow

```bash
# 1. Get current item state
op item get "<Title>" --vault="$OP_VAULT" --format=json

# 2. Update specific field
op item edit "<Title>" "<field>=<value>" --vault="$OP_VAULT"

# 3. MUST validate after update
op item get "<Title>" --vault="$OP_VAULT" --format=json
```

---

## 1Password compliance

### What makes an item compliant

An item is compliant if ALL of these are true:
- [ ] Correct category (see Categories table)
- [ ] Correct naming convention (see Naming table)
- [ ] No duplicate items for same service
- [ ] API keys/files linked to login item (if applicable)
- [ ] No secrets duplicated across items

### Self-heal: detect non-compliant items

```bash
# List all items for review
op item list --vault="$OP_VAULT" --format=json | jq -r '.[] | "\(.category): \(.title)"'
```

Check for:
- Wrong category (e.g., `Password` instead of `API Credential`)
- Wrong naming (e.g., `GitHub Login` instead of `GitHub`)
- Missing links (API key without `Linked login:` note)
- Duplicates (multiple items for same service)

### Self-heal: fix non-compliant items

**Wrong category:** Cannot change category. MUST create new item with correct category, migrate data, delete old item.

**Wrong naming:**
```bash
op item edit "<old title>" title="<new title>" --vault="$OP_VAULT"
```

**Missing link:**
```bash
# Get login item ID first
op item get "<Login title>" --vault="$OP_VAULT" --format=json | jq -r '.id'

# Add link to API key item
op item edit "<API key title>" notesPlain="Linked login: <Login title> (item_id: <id>)" --vault="$OP_VAULT"
```

**Duplicates:** Merge data into one item, delete the other. Prefer keeping the older/more complete item.

---

## 1Password CLI reference

### Read

```bash
op read "op://<vault>/<item>/<field>"
op read "op://$OP_VAULT/GitHub/password"
```

### Create

```bash
# Login
op item create --category="Login" --title="<Service>" --vault="$OP_VAULT" \
  username="<email>" password="<password>"

# API key
op item create --category="API Credential" --title="<Service> - API key" --vault="$OP_VAULT" \
  credential="<token>"

# SSH key
op item create --category="SSH Key" --title="id_ed25519" --vault="$OP_VAULT" \
  --ssh-key="$HOME/.ssh/id_ed25519"
```

### Update

```bash
op item edit "<title>" "<field>=<value>" --vault="$OP_VAULT"
```

### Validate

```bash
op item get "<title>" --vault="$OP_VAULT" --format=json
```

### List

```bash
op item list --vault="$OP_VAULT" --format=json
```

---

## chezmoi operations

### Source directory

```
~/.local/share/chezmoi/          # chezmoi source (this repo)
├── .chezmoiroot                 # points to home/
├── home/                        # actual dotfiles
│   ├── .chezmoi.toml.tmpl       # init prompts
│   ├── .chezmoiscripts/         # run_once scripts
│   ├── dot_zshrc
│   └── private_dot_*/           # private files
├── policies/                    # reference docs
└── skills/                      # AI-executable procedures
```

### Common commands

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

### Template variables

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

### 1Password in templates

```
{{ onepasswordRead "op://<vault>/<item>/<field>" }}
{{ onepasswordRead "op://Berry Bolt/Telegram Bot - API key/credential" | quote }}
```

### Adding a new dotfile

1. Create or edit the file in your home directory
2. Add to chezmoi: `chezmoi add ~/.newfile`
3. If it needs templating: `chezmoi add --template ~/.newfile`
4. Edit template if needed: `chezmoi edit ~/.newfile`
5. Verify: `chezmoi diff`
6. Commit: see git practices below

### run_once scripts

Location: `home/.chezmoiscripts/<os>/`

Naming: `run_once_before_<order>-<name>.sh.tmpl`

Example: `run_once_before_01-restore-ssh-key.sh.tmpl`

Scripts run once per machine (tracked by checksum).

---

## Git practices (dotfiles repo)

### Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>[optional scope]: <description>

[optional body]
```

Common types: `feat`, `fix`, `docs`, `refactor`, `chore`

Examples:
```
feat: add mise config for node/python versions
fix: chezmoi template syntax for openclaw.json
refactor: reorganize repo with home/ as chezmoi root
docs: update credentials policy with strict invariants
chore: add starship and zoxide to Brewfile
```

### Atomic commits

- Each commit SHOULD contain one logical change
- Group related changes together (e.g., new dotfile + its template variables)
- MUST NOT mix unrelated changes in one commit
- If a change spans multiple files for one purpose, that's one commit

### Sync with upstream

- MUST pull before starting work: `git -C ~/.local/share/chezmoi pull`
- MUST push after each commit (or batch of related commits)
- SHOULD NOT leave uncommitted changes overnight

### Prohibited operations

- MUST NOT rebase
- MUST NOT force push (`--force`, `-f`)
- MUST NOT reset (`git reset --hard`)
- MUST NOT amend pushed commits

### What to commit

MUST commit:
- All dotfiles in `home/`
- Templates (`.tmpl` files)
- Policies and skills
- Brewfile
- run_once scripts

MUST NOT commit:
- Secrets or tokens (use 1Password + templates)
- `~/.config/chezmoi/chezmoi.toml` (machine-specific, has token)
- Large binary files
- OS-generated files (`.DS_Store`)

### Commit workflow

```bash
# Check status
git -C ~/.local/share/chezmoi status

# Stage specific files
git -C ~/.local/share/chezmoi add home/dot_zshrc

# Commit
git -C ~/.local/share/chezmoi commit -m "update: add zoxide aliases"

# Push
git -C ~/.local/share/chezmoi push
```

### After modifying a managed file

If you edit a file that chezmoi manages (e.g., `~/.zshrc`):

1. Check diff: `chezmoi diff`
2. If changes should persist, update source: `chezmoi add ~/.zshrc`
3. Commit the change
4. Push

---

## Account/credential creation workflow

When a new service credential is needed:

1. **Check 1Password first**
   ```bash
   op item list --vault="$OP_VAULT" | grep -i "<service>"
   ```

2. **If not found, create programmatically** (if service supports it)
   - Use API/CLI to generate token
   - Immediately store in 1Password (see naming conventions)

3. **Update chezmoi template** (if needed)
   - Add 1Password reference to template
   - Test: `chezmoi cat <file>`
   - Apply: `chezmoi apply`
   - Commit

4. **Rotate if compromised**
   - Revoke old credential at service
   - Generate new credential
   - Update 1Password item
   - `chezmoi apply` (templates auto-update)

---

## Skills

Procedural knowledge for complex operations. See `skills/` directory.

Available skills:
- `1password-setup` — Service account setup, CLI configuration (TODO)

Skills follow the [Agent Skills](https://agentskills.io) format.

---

## Change log

- 2026-02-01: added strict invariants (categories, naming, workflows); added compliance checks and self-heal procedures.
- 2026-02-01: rewritten as self-serve ops manual; removed escalation guardrails.
- 2026-01-27: initial draft.
