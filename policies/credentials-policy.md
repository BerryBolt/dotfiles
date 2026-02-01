# Credentials policy

## Normative language (RFC 2119/8174)

- **MUST:** Absolute requirement.
- **MUST NOT:** Absolute prohibition.
- **SHOULD:** Strong recommendation; deviate only with a valid, documented reason.
- **SHOULD NOT:** Strong discouragement; deviate only with a valid, documented reason.
- **MAY:** Permission; allowed but not required.

---

## Purpose

Defines how you store, discover, and use credentials and secrets. 1Password is the **source of truth** for anything you can access.

## Security posture

- MUST NOT paste secrets (API keys/tokens/passwords) into chat, logs, code, or committed files.
- SHOULD use in-memory workflows (e.g., `op run`, `op inject`) rather than writing secrets to disk.
- When a new secret is created/obtained, it MUST be stored in 1Password immediately with consistent naming.

---

## Operational assumptions

- You have a dedicated 1Password account.
- Access is provided via environment variables:
  - `OP_SERVICE_ACCOUNT_TOKEN` (MUST NOT be printed or logged)
  - `OP_VAULT`
- Most secret retrieval SHOULD be possible non-interactively via the 1Password CLI.
- If you don't have access to 1Password, ask the account owner to grant you access.

---

## Source-of-truth rules

When asked to enable/configure a tool:

1. MUST search 1Password first for existing credentials/keys.
2. If not found, MUST attempt to create the credential programmatically (if possible) using your identity.
3. MUST store the new credential in 1Password before proceeding with configuration.

Only ask the account owner when:

- The resource requires an account/payment outside your scope, or
- Access requires human approval (device prompt, billing, etc.).

---

## Programmatic-first access order

For any service/tool integration, use this order:

1. API/CLI auth (token/key/OAuth) via scripted flow
2. SDK / direct HTTP integration (if supported and safer)
3. Browser automation (fallback only)

---

## 1Password CLI usage policy

- SHOULD NOT rely on macOS Keychain or other OS-specific secret stores; prefer portable, OS-agnostic workflows.
- For service-account setup and CLI usage instructions, see the `1password-setup` skill.

### CLI interaction guardrails

- When using interactive sign-in flows, SHOULD run `op` inside a tmux session to avoid TTY/prompt issues.
- SHOULD validate access before use:
  - `op whoami`
  - `op vault list`

---

## Vaults

- MUST use `OP_VAULT` as the default target for created items.
- If a secret must live in a different vault, MUST record that in the item title or tags.

---

## Naming conventions

### API keys

- `<Service> - API key`
  - Examples:
    - `Brave Search - API key`
    - `Firecrawl - API key`

### Logins

- `<Service name>` for your accounts (no "Login" label)
  - Examples: `GitHub`, `Brave`

### Credential files

- `<Service> - Credential File`
  - Example: `Google Cloud - Credential File`

---

## Item structure + linking

### What goes where

- **Login items:** interactive sign-in credentials only (email/username, password, 2FA, recovery codes).
- **API key items:** non-interactive tokens/keys (one item per key).
- **Credential file items:** JSON/PEM/etc. stored as 1Password **Document** items.

### Default rule (separate items)

- API keys/tokens MUST be stored in their own 1Password item (one item per key).
- Login items MUST only contain account credentials (email/username, password, 2FA, recovery codes).
- Credential files (JSON/PEM/etc.) MUST be stored as 1Password Document items, one file per item.
- API key items MUST be linked to the originating login item:
  - In CLI-only flows, add a note or custom field like `Linked login: <Login item title> (<account email>, item_id: <id>)`.
  - If a UI is ever used, you MAY also add **Related Items** for convenience.
- Credential file items MUST be linked to the originating login item using the same approach.
- MUST NOT duplicate the secret value in both items (avoid drift).

Rationale: separating keys/files from logins prevents duplication drift, makes rotation and scoping clearer, supports multiple keys/environments, and enables safer sharing/automation without exposing full account credentials.

### Exceptions (rare)

- If a service supports exactly one key and the key is only for occasional manual use, the API key MAY be stored as a custom field on the login item.
- If the key is used by automation or multiple keys exist, you SHOULD still create a dedicated API key item even if a custom field exists.

### Notes / metadata

- Keep a short “How to rotate” note in the item.
- Include the intended purpose/use-case in the item notes (instead of the title).
- Include relevant URLs and account identifiers (email), not the secret in notes if it’s already in a password field.
- If a credential file must be written to disk, SHOULD write to a temporary path with tight permissions and delete it after use.

### Referencing items

- Documentation and runbooks SHOULD reference credentials by 1Password **item_id** (or a stable link that includes it), not by name or other means. If it changes, you MUST update all references.

---

## Rotation + recovery

- If a token is suspected leaked, MUST rotate immediately and update the 1Password item.
- SHOULD create tokens with least privilege and scoped to your use.

---

## Change log

- 2026-02-01: made runtime-agnostic; fixed em-dashes in naming conventions; removed open questions section.
- 2026-01-27: initial draft created (1Password is source of truth; programmatic-first).
