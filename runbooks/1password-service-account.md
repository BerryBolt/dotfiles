# 1Password service account

## Goal

Use 1Password CLI non-interactively through a service account, with the token scoped to single commands.

## Prerequisites

- Follow `policies/credentials.md`.
- You have a service account token. See `skills/1password-setup/SKILL.md` for how to create one.

## How the env file is managed

`~/.config/op/env` is the single source of truth for all OP_* env vars at rest. It is rendered by chezmoi from [home/dot_config/private_op/private_env.tmpl](../home/dot_config/private_op/private_env.tmpl) at mode 0600:

| Variable                   | Source at render time                                           |
| -------------------------- | --------------------------------------------------------------- |
| `OP_SERVICE_ACCOUNT_TOKEN` | chezmoi process env (`env "OP_SERVICE_ACCOUNT_TOKEN"`)          |
| `OP_VAULT`                 | chezmoi data: `op_vault`                                        |
| `OP_FORMAT`                | hardcoded `"json"`                                              |

The token is NOT persisted in chezmoi data. It reaches the template only through the process env of whichever chezmoi invocation is rendering. On first bootstrap `install.sh` exports it; on subsequent applies `chezmoi-with-op` sources this same file before invoking chezmoi and re-supplies the token that way. A token the caller supplies to `chezmoi-with-op` for one command takes precedence over the file; that is how the file is restored or rotated (below). A bare `chezmoi apply` without `chezmoi-with-op` will fail fast via a template guard rather than silently clobber the file with an empty token.

You MUST NOT hand-edit `~/.config/op/env`. It is a chezmoi-managed target and any edit will be overwritten on the next `chezmoi apply`. To change the vault, use the data-rotation workflow in `policies/chezmoi.md`. To rotate the token, see "Rotate the token" below.

The file is NEVER sourced into a parent shell — only into one-shot child processes started by the wrappers. The file's consumers are:
- `with-op` at `~/.local/bin/with-op`, and the interactive `op` function in the dotfiles block of `~/.bashrc` that calls it
- `chezmoi-with-op` at `~/.local/bin/chezmoi-with-op`
- `run_after_30-restore-ssh-key.sh` (fallback load when chezmoi runs without the token in its env)

## Verify service-account access

```bash
op whoami
op vault list
```

In an interactive Bash terminal, the `op` function loads `~/.config/op/env` automatically per call; from scripts, use `with-op op ...`. `OP_FORMAT=json` is set inside the wrapper process, so you do not need `--format json` explicitly. See `policies/credentials.md` for the wrapper architecture.

Expected:
- `op whoami` returns `user_type: SERVICE_ACCOUNT`.
- `op vault list` includes the target vault.
- Secrets can be read without an interactive sign-in.

## Rotate the token

The token is not stored in chezmoi data. Supply the new token to `chezmoi-with-op` for one apply; it takes precedence over the old value in the file and re-renders `~/.config/op/env`.

1. Generate a new token in the 1Password web console → Settings → Automation → Service Accounts.
2. In a terminal, without putting the token in history or the parent environment:
   ```bash
   read -rsp 'New token: ' t && OP_SERVICE_ACCOUNT_TOKEN=$t chezmoi-with-op apply; unset t
   ```
3. `op whoami` — verify the new token works.
4. Revoke the old token.

## Restore a missing env file

If `~/.config/op/env` was deleted, `op`, `with-op`, and `chezmoi-with-op` fail with the restore command. Supply the token for one command and restore only that file:

```bash
read -rsp 'Token: ' t && OP_SERVICE_ACCOUNT_TOKEN=$t chezmoi-with-op apply --force ~/.config/op/env; unset t
```

`--force` is required because chezmoi treats a deleted managed file as a local change and would otherwise ask before recreating it. Naming the target limits it to this file. The file comes back at mode 0600 in a 0700 directory; run `op whoami` to confirm.

## Rotate the SSH signing key

The SSH key is stored in the 1Password SSH Key item selected by chezmoi data `op_ssh_item` (title or item ID; see `chezmoi data`) and installed as `~/.ssh/id_ed25519`. It is used both for signing git commits and for the chezmoi source repo's SSH remote. Rotation must update that 1Password item; every managed machine will pick up the new key on its next `chezmoi-with-op apply`.

1. Generate a new key pair locally (or let 1Password generate one).
2. Update the item at `op://{op_vault}/{op_ssh_item}`:
   - replace the `private key` field with the new private key
   - replace the `public key` field with the new public key
3. Add the new public key to GitHub (or wherever it grants access) BEFORE continuing to step 4, so existing machines do not lock themselves out.
4. On each machine, run `chezmoi-with-op apply`.

What `chezmoi apply` does on step 4:

- `allowed_signers` is re-rendered from `onepasswordRead` — git now trusts the new public key.
- `run_after_30-restore-ssh-key.sh` compares the on-disk public key to 1Password's current public key. On a mismatch it fetches the new private key to a temporary file and verifies that it matches the item's public key. Only then does it move the old key to `~/.ssh/id_ed25519.stale.<timestamp>` and install the new one. If the item's private and public keys disagree, apply stops and the current key stays in place.
- Git commits signed from this point on use the new key and verify against the new `allowed_signers`.

If 1Password is unreachable when you run apply, or the on-disk key cannot be validated, `run_after_30-restore-ssh-key.sh` exits non-zero and the apply stops. Restore 1Password connectivity or fix the local key state before retrying.

**Clean up stale backups** when you are confident the rotation is stable on the machine:

```bash
ls ~/.ssh/id_ed25519.stale.*
rm ~/.ssh/id_ed25519.stale.<timestamp> ~/.ssh/id_ed25519.pub.stale.<timestamp>
```

## Troubleshooting

| Symptom                                    | Cause / Fix                                                                 |
| ------------------------------------------ | --------------------------------------------------------------------------- |
| Write fails with `(101) You do not have permission` | Service account lacks vault write permissions. Update in 1Password web console. |
| chezmoi templates prompt for or reject 1Password sign-in | `[onepassword] mode` is not `service` in `~/.config/chezmoi/chezmoi.toml`, or chezmoi ran without `chezmoi-with-op`. |
| `~/.config/op/env not found` from `with-op` or `chezmoi-with-op` | The env file is missing. See "Restore a missing env file". |
| `op whoami` returns a non-service user     | Token in `env` is a personal token, not a service account. Rotate per above. |

## Storage pattern for binary and JSON secrets

- Credential files such as JSON and PEM material MUST be stored as 1Password `Document` items.
- Those document items MUST be linked back to the relevant login item using an `item_id`.
- If a credential file is exported for use, it SHOULD be written to a temporary file with tight permissions and removed after use.
