---
name: 1password-setup
description: Set up 1Password service account and CLI for non-interactive access. Use when bootstrapping a new machine or agent that needs 1Password access.
---

# 1Password Setup

Set up 1Password CLI with a service account for non-interactive (automated) access.

## Prerequisites

- 1Password account with admin access
- 1Password CLI installed (`op` command available)

## Steps

### 1. Create Service Account (requires human)

This step requires human action in the 1Password web console:

1. Go to https://my.1password.com → Settings → Automation → Service Accounts
2. Click "Create Service Account"
3. Name it (e.g., "Berry Bolt Agent")
4. Select vault access (grant access to the agent's vault)
5. Copy the service account token (shown once)

**Important:** The token is shown only once. Store it in a vault the service account itself has NO access to (typically your personal vault) — not in the agent's own vault. See [policies/credentials.md § Vault rules](../../policies/credentials.md#vault-rules) for the rationale.

### 2. Store Token

Provide the token to `install.sh` when prompted (see repo [README.md](../../README.md)). `install.sh` exports it into chezmoi's process env, and chezmoi renders it into `~/.config/op/env` (mode 0600). That file is the single source of truth for all OP_* env vars at rest. The token is NOT persisted in chezmoi data.

### 3. Validate Access

After bootstrap, open a new Omarchy terminal. The `op` shell function loads `~/.config/op/env` into the command's process on each call, so you just run `op` directly (from scripts, use `with-op op ...`):

```bash
op whoami
op vault list
```

Expected output shows the service account name and accessible vaults.

### 4. Test Read Access

```bash
op item list
```

Should list items in the default vault. The wrapper subshell has `OP_VAULT` set, so no `--vault` flag is needed.

## Troubleshooting

### "not authorized"
- Check vault permissions in service account settings
- Verify token is correct and not expired

### "vault not found"
- Vault name is case-sensitive
- Check `op vault list` for exact names

### Token rotation
If token is compromised:
1. Go to 1Password web console → Service Accounts
2. Revoke old token
3. Create new token
4. Re-render `~/.config/op/env` with the new token: `read -rsp 'Token: ' t && OP_SERVICE_ACCOUNT_TOKEN=$t chezmoi-with-op apply; unset t` (see [runbooks/1password-service-account.md](../../runbooks/1password-service-account.md#rotate-the-token))
5. `op whoami` to verify

## References

- [1Password Service Accounts](https://developer.1password.com/docs/service-accounts/)
- [1Password CLI](https://developer.1password.com/docs/cli/)
- [policies/credentials.md](../../policies/credentials.md)
