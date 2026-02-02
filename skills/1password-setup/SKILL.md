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

**Important:** The token is shown only once. Store it securely.

### 2. Store Token

The token should be provided during `chezmoi init` and stored in:
- `~/.config/chezmoi/chezmoi.toml` (for chezmoi templates)

### 3. Validate Access

```bash
export OP_SERVICE_ACCOUNT_TOKEN="<token>"
op whoami
op vault list
```

Expected output shows the service account name and accessible vaults.

### 4. Test Read Access

```bash
op item list --vault="$OP_VAULT"
```

Should list items in the vault.

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
4. Update `~/.config/chezmoi/chezmoi.toml`
5. Run `chezmoi apply` to update dependent files

## References

- [1Password Service Accounts](https://developer.1password.com/docs/service-accounts/)
- [1Password CLI](https://developer.1password.com/docs/cli/)
- [policies/credentials.md](../../policies/credentials.md)
