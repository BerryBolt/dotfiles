# Credentials

1Password operations, invariants, and compliance.

## Security posture

- MUST treat 1Password as the source of truth for credentials and secrets you can access.
- MUST NOT paste secrets into chat, logs, code, or committed files.
- SHOULD prefer in-memory workflows such as `op run` or `op inject` over writing secrets to disk.
- When a new secret is created or obtained, it MUST be stored in 1Password immediately using the conventions in this policy.

## Access model

The agent works like an employee with its own accounts: it signs up for services, keeps its own logins, and stores the credentials it creates. Its only 1Password identity is its own service account.

- MUST access 1Password only through the agent's service account, scoped to the agent's vault. The agent has no 1Password user account, so it MUST NOT depend on the desktop app, the browser extension, the 1Password SSH agent, shell plugins, or `op signin`.
- A user account does not fit an unattended agent. Those apps unlock with a master password or system authentication, which assumes a person at the keyboard; unlocking them unattended would mean keeping the master password on the workstation. A service account works unattended, reaches only the vaults it was granted, is revoked on its own, and its access appears in the account's activity log.
- The service account has read and write item permissions (`read_items`, `write_items`) in the agent's vault, and no sharing or vault-management permissions. The agent stores every credential it creates or receives there (see Workflows).
- The human owner administers the 1Password account and keeps the service-account token outside the agent's vault (see Vault rules).
- Service-account permissions are fixed at creation. To change vaults or permissions, create a replacement service account and [rotate the token](../runbooks/1password-service-account.md#rotate-the-token).

### Runtime sign-ins

CLIs with their own OAuth sign-in keep that session as runtime state, not configuration. The repo installs them; the agent signs in itself and signs in again after a restore:

| CLI | Sign-in | Session stored in |
| --- | --- | --- |
| `gh` | `gh auth login --web` | `~/.config/gh/` |
| `wrangler` | `wrangler login` | `~/.config/.wrangler/` |
| `xurl` | `xurl auth oauth2 --headless`, with the developer app's client ID and secret from 1Password in the environment | `~/.xurl` (refresh tokens rotate on every use) |

The agent MUST NOT print or read these session files or tokens into its own context.

## Environment setup

Required environment variables for `op`:
- `OP_SERVICE_ACCOUNT_TOKEN` — service account token (MUST NOT log or print)
- `OP_VAULT` — default vault name
- `OP_FORMAT` — default CLI output format; use `json` in this environment

Single source of truth: **`~/.config/op/env`** holds all three. It is chezmoi-managed at mode 0600 and is NEVER sourced into a parent shell. The wrappers load it into a one-shot child process for the duration of a single command:

| Wrapper | Where | Available in |
| --- | --- | --- |
| `op` | Shell function in the dotfiles block of `~/.bashrc` (`with-op op "$@"`) | Interactive Bash |
| `with-op` | `~/.local/bin/with-op` | Any caller; prepends the mise shims and `~/.local/bin` to `PATH` |
| `chezmoi-with-op` | `~/.local/bin/chezmoi-with-op` | Any caller; same `PATH` handling |

| Variable                   | Sensitive? | Visible in interactive shell? | How commands see it                       |
| -------------------------- | ---------- | ----------------------------- | ----------------------------------------- |
| `OP_SERVICE_ACCOUNT_TOKEN` | Yes        | No                            | Wrapper subshell only                     |
| `OP_VAULT`                 | No         | No                            | Wrapper subshell only                     |
| `OP_FORMAT`                | No         | No                            | Wrapper subshell only                     |

None of the three are exported into the parent shell. This prevents the token from leaking to subprocesses (package installs, git hooks, IDE extensions, build scripts) and keeps all OP config centralized in one file.

**Practical consequence:** `$OP_VAULT` does NOT expand in your interactive shell. See "Calling `op`" below for the two idioms that replace inline `$OP_VAULT` expansion.

### Calling `op`

In an interactive Bash terminal, `op` is a shell function that runs `with-op op`, loading `~/.config/op/env` for the duration of the call. Just run `op` normally:

```bash
op whoami
op vault list
op item list
op item get "<Title>"
```

The token (and the other OP_* vars) only exist in the process that runs the binary. The parent shell and its other children never see them. Scripts and other non-interactive callers do not get the function; they call `with-op op ...` instead.

### When you need `$OP_VAULT` inline

Commands that embed the vault in an `op://` URI need `$OP_VAULT` to expand where the command runs. Since the parent shell doesn't have `OP_VAULT` set, wrap the command in `with-op bash -c '...'` so expansion happens inside the subshell that does:

```bash
with-op bash -c 'op read "op://$OP_VAULT/GitHub/password"'
```

Use single quotes around the `-c` string so `$OP_VAULT` is expanded by the subshell, not the parent.

### Calling other tools that need the token

Use the `with-op` wrapper to scope the env load to a single command:

```bash
with-op python my-1p-script.py
with-op terraform apply
```

### Manual loading (avoid)

You SHOULD NOT do `set -a; source ~/.config/op/env; set +a` in interactive shells. It pollutes the shell env with the token, which then leaks to every subprocess started from that shell. Use `op`, `with-op`, or `chezmoi-with-op` instead.

Manual sourcing is acceptable inside scripts that exit when they finish, where the env dies with the script.

## Operational assumptions

- Access SHOULD be available non-interactively through the 1Password CLI.
- The default env file for `op` and `chezmoi-with-op` is `~/.config/op/env`.
- The managed runtime env SHOULD set `OP_FORMAT=json` so agent-driven `op` commands default to machine-readable output.
- If you do not have access to 1Password, you MUST stop and ask for access rather than inventing an alternate secret store.

## Validate access

Before using 1Password, MUST validate:

```bash
op whoami --format json
op vault list --format json
```

The `op` shell wrapper loads `~/.config/op/env` for each call automatically (see Environment setup).

### CLI interaction guardrails

- SHOULD run interactive `op` flows inside `tmux` when prompt handling or TTY behavior is unreliable.
- SHOULD validate access before reading or writing items.

---

## Invariants (strict)

### Categories (mandatory)

| Use case | Category | CLI flag |
|----------|----------|----------|
| Website/service login | `Login` | `--category="Login"` |
| Workstation account (the agent's OS login) | `Server` | `--category="Server"` |
| API key or token | `API Credential` | `--category="API Credential"` |
| SSH key | `SSH Key` | `--category="SSH Key"` |
| Credential file (JSON/PEM) | `Document` | `--category="Document"` |

MUST use the correct category. MUST NOT use generic categories like `Password` or `Secure Note` for credentials.

### Naming conventions (mandatory)

| Type | Pattern | Examples |
|------|---------|----------|
| Login | `<Service>` | `GitHub`, `Brave`, `Notion` |
| Workstation account | `<hostname>` | The VM's hostname |
| API key | `<Service> - API key` | `Brave Search - API key`, `Firecrawl - API key` |
| Credential file | `<Service> - Credential File` | `Google Cloud - Credential File` |
| SSH key | `<key filename>` | `id_ed25519` (new items) |

Rules:
- MUST use regular hyphen (` - `), MUST NOT use em-dash (`—`)
- MUST NOT include "Login" suffix in login item titles
- MUST NOT include "API key" in login items (separate item)
- Service name MUST match official name (e.g., `GitHub` not `Github` or `github`)
- The bootstrap selects its SSH Key item through the `op_ssh_item` chezmoi value (title or item ID), not by the naming convention. Prefer the item ID there so renaming the item cannot break key restoration.
- Integrations reference their items by the naming-convention title, for example `Purelymail` for the agent's mailbox, so those titles MUST follow the convention.
- The bootstrap selects the workstation account item through the `op_account_item` chezmoi value (title or item ID); prefer the item ID for the same reason. Its `username` must be the installed account.

### Item structure (mandatory)

| Item type | Required fields | Optional fields |
|-----------|-----------------|-----------------|
| Login | username, password | website, 2FA (totp), recovery codes |
| Server (workstation account) | username, password in the main section | URL; leave the Admin Console and Hosting Provider sections empty |
| API Credential | credential | notes (linked login) |
| SSH Key | private_key | - |
| Document | file attachment | notes (linked login) |

### Linking rules

- API key items MUST include note: `Linked login: <Login title> (item_id: <id>)`
- Credential files MUST include note: `Linked login: <Login title> (item_id: <id>)`
- MUST NOT duplicate the secret value in both linked items

### Vault rules

- MUST use `OP_VAULT` as the default target for created items.
- If a secret must live in a different vault, MUST record that clearly in the item notes or tags.
- **Service account token placement.** The service account token MUST NOT live in a vault the service account has write access to. Store it in a vault only reachable by your personal account (typically your personal vault). Rationale: the agent operates on `$OP_VAULT` with read-write access per the workflows below, so anything in that vault is within reach of the agent's own edit/delete operations — keeping the token outside it prevents the agent from accidentally mutating its own access credential.

### No duplicates

- MUST NOT create multiple items for the same service/credential
- Before creating: MUST search existing items (see workflow below)

---

## Workflows (strict order)

All command snippets below use the `op` shell wrapper, which loads `~/.config/op/env` into a subshell on each call. Because `OP_VAULT` and `OP_FORMAT` are set inside that subshell, you do NOT pass `--vault` or `--format` explicitly — `op` picks them up from the subshell env. See Environment setup.

### Before ANY create operation

```bash
# 1. MUST search first
op item list | jq -r '.[].title' | grep -i "<service>"

# 2. If found → STOP. Use existing item or update it.
# 3. If not found → proceed to create
```

### Create workflow

```bash
# 1. Search (see above) - MUST do this first
# 2. Create with correct category and naming
op item create --category="<Category>" \
  --title="<Title per naming convention>" \
  <fields>

# 3. MUST validate immediately after
op item get "<Title>"

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
op item get "<Title>"

# 2. Update specific field
op item edit "<Title>" "<field>=<value>"

# 3. MUST validate after update
op item get "<Title>"
```

### Account/credential creation workflow

When a new service credential is needed:

1. **Check 1Password first**
   ```bash
   op item list | grep -i "<service>"
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

### Storage exceptions

- MAY store a one-off manual-use API key as a custom field on a login item only when the service supports exactly one key and automation is not involved.
- SHOULD still create a dedicated `API Credential` item when the key is used by automation, rotation, or multiple environments.

### Notes and metadata

- SHOULD keep a short rotation note in the item.
- SHOULD record purpose and account identifiers in notes rather than overloading the title.
- If a credential file must be written to disk, SHOULD use a temporary path with tight permissions and delete it after use.

### Documentation references

- Runbooks and operational docs SHOULD reference 1Password items by `item_id` when traceability matters.
- If an item reference changes, you MUST update the docs that depend on it.

---

## Compliance

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
op item list | jq -r '.[] | "\(.category): \(.title)"'
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
op item edit "<old title>" title="<new title>"
```

**Missing link:**
```bash
# Get login item ID first
op item get "<Login title>" | jq -r '.id'

# Add link to API key item
op item edit "<API key title>" notesPlain="Linked login: <Login title> (item_id: <id>)"
```

**Duplicates:** Merge data into one item, delete the other. Prefer keeping the older/more complete item.

---

## Rotation and recovery

- MUST rotate a token immediately if it is suspected to be leaked.
- SHOULD use least privilege when creating new credentials.

---

## CLI reference

### Read

```bash
# The op wrapper loads OP_* env vars on demand into its subshell.
# Literal vault names work in op:// URIs; to use $OP_VAULT, wrap in
# `with-op bash -c '...'` so expansion happens inside the subshell.
op read "op://<vault>/<item>/<field>"
with-op bash -c 'op read "op://$OP_VAULT/GitHub/password"'
```

### Create

The wrapper's subshell has `OP_VAULT` set, so `op` targets it by default — no `--vault` flag needed.

```bash
# Login
op item create --category="Login" --title="<Service>" \
  username="<email>" password="<password>"

# API key
op item create --category="API Credential" --title="<Service> - API key" \
  credential="<token>"

# SSH key
op item create --category="SSH Key" --title="id_ed25519" \
  --ssh-key="$HOME/.ssh/id_ed25519"
```

### Update

```bash
op item edit "<title>" "<field>=<value>"
```

### Validate

```bash
op item get "<title>"
```

### List

```bash
op item list
```
