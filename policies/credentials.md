# Credentials

1Password operations, invariants, and compliance.

## Environment setup

Required environment variables (set before any `op` commands):
- `OP_SERVICE_ACCOUNT_TOKEN` — service account token (MUST NOT log or print)
- `OP_VAULT` — default vault name

## Validate access

Before using 1Password, MUST validate:

```bash
op whoami
op vault list
```

---

## Invariants (strict)

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

## Workflows (strict order)

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

### Account/credential creation workflow

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

## CLI reference

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
