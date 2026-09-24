# Dotfiles

Chezmoi-managed fundamentals for an Omarchy agent workstation: Bash integration, scoped 1Password access, Git/SSH, and repeatable user configuration.

**Status:** fresh install, repeat install, reapply, recovery, login, and restart checks pass on a disposable Omarchy 4.0.4 (x86_64) VM.

Read [VISION.md](VISION.md) for scope and [ARCHITECTURE.md](ARCHITECTURE.md) for the bootstrap flow, managed state, and recovery contract.

## Prerequisites

- An installed Omarchy workstation and the intended user account, provided by the platform owner. Run the installer as that user, not root.
- Omarchy's default Bash, Git, OpenSSH, and mise. The installer checks for them and stops with an error if one is missing; it does not install system packages.
- A 1Password service-account token scoped to the intended vault.
- An SSH Key item in that vault, with a valid OpenSSH private key and matching public key suitable for unattended use. The installer selects it by title or item ID (`CHEZMOI_OP_SSH_ITEM`); an ID keeps working if the item is renamed. It is always installed as `~/.ssh/id_ed25519`, whatever the item is called.
- That public key registered to the intended GitHub account for authentication and signing, with read access to the dotfiles repository.

See [the 1Password setup procedure](skills/1password-setup/SKILL.md) for account preparation.

No model provider, Telegram bot, agent runtime, or workspace repository is required.

## Install

```bash
curl -fsSL https://berrybolt.bot/install.sh | bash
```

The installer prompts for the account name, email, GitHub handle, vault, SSH key item, and token, then shows a review step. For an unattended run, set every input in the environment and pass `--non-interactive`. Keep the token inside a subshell, off the command line and out of shell history:

```bash
(
  read -rsp 'Service account token: ' OP_SERVICE_ACCOUNT_TOKEN && echo
  export OP_SERVICE_ACCOUNT_TOKEN
  export CHEZMOI_AGENT_NAME="..." CHEZMOI_AGENT_EMAIL="..." \
    CHEZMOI_AGENT_HANDLE_GITHUB="..." CHEZMOI_OP_VAULT="..." CHEZMOI_OP_SSH_ITEM="..."
  curl -fsSL https://berrybolt.bot/install.sh | bash -s -- --non-interactive
)
```

`https://berrybolt.bot/install.sh` redirects to `install.sh` on this repository's `main` branch.

The source comes from `https://github.com/<GitHub handle>/dotfiles.git`, on its default branch unless you pin a revision.

### Install an exact revision

To test a pushed commit, fetch the installer and apply the source from the same full SHA:

```bash
sha=<full-40-character-commit-sha>
curl -fsSL "https://raw.githubusercontent.com/BerryBolt/dotfiles/$sha/install.sh" \
  | bash -s -- --revision "$sha"
```

`--revision` (or `DOTFILES_REVISION`) accepts only a full commit SHA. On a fresh install the installer clones the repository and detaches at that commit. On a repeat install it fetches the commit over the existing SSH remote when needed and detaches there. It stops if the commit cannot be fetched or the existing source has local modifications. A later run without `--revision` refuses a detached source instead of silently moving it.

## Result

Open a normal Omarchy terminal:

```bash
op whoami                    # service account; the token stays in op's subshell
with-op bash -c 'op read "op://$OP_VAULT/<item>/<field>"'
chezmoi-with-op apply        # reapply managed files and SSH restoration
ssh -T git@github.com        # authenticates with the restored key
git commit -S ...            # commits are signed by default
```

Omarchy remains responsible for its desktop, shell defaults, and existing tools. This repo adds only the account configuration listed in [Managed state](ARCHITECTURE.md#managed-state). See [the recovery contract](ARCHITECTURE.md#recovery) for the limited repair scope.

## Layout

| Path | Role |
| --- | --- |
| `home/` | Chezmoi-managed user files and apply scripts |
| `install.sh` | Bootstrap entry point |
| `policies/` | Configuration, credential, dependency, and Git rules |
| `runbooks/` | Operational procedures |
| `skills/` | Bootstrap procedures |
| `tests/` | Local regression checks, target-side fundamentals assertions, and recovery acceptance |

## Validation

- `tests/regression.sh` — run on a development host. It needs `bash`, `git`, `ssh-keygen`, and `chezmoi`, but no credentials. It applies into a throwaway home and never touches the real one.
- `tests/assertions.sh` — run as the installed user on the Omarchy target with `CHEZMOI_AGENT_EMAIL` and `CHEZMOI_AGENT_HANDLE_GITHUB` set. It uses live 1Password and GitHub access and creates one local signed commit in a temporary repository, which it never pushes.
- `tests/recovery.sh` — **destructive; disposable or test accounts only.** It deletes and restores the SSH key and the credential env file, and simulates a rotated key with a generated fixture key. It reads the token from stdin for the env-file restore. The live 1Password item and GitHub registration are not changed.

Acceptance testing installs a pushed candidate from the public GitHub repository on a disposable Omarchy VM. Supply `OP_SERVICE_ACCOUNT_TOKEN` through ignored local configuration and use [tests/.env.local.example](tests/.env.local.example) for the remaining input names. Actual tokens, vault/account values, VM addresses, logins, and private platform records are local operational inputs.

## License

MIT
