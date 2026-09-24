# Dotfiles

Chezmoi-managed fundamentals for an Omarchy agent workstation: Bash integration, scoped 1Password access, Git/SSH, and repeatable user configuration.

**Status:** candidate implementation under acceptance testing on a disposable Omarchy VM. It is not yet merged to `main` or served by the bootstrap endpoint.

Read [VISION.md](VISION.md) for scope and [ARCHITECTURE.md](ARCHITECTURE.md) for the bootstrap flow, managed state, and recovery contract.

## Prerequisites

- An installed Omarchy workstation and the intended user account, provided by the platform owner. Run the installer as that user, not root.
- Omarchy's default Bash, Git, OpenSSH, and mise. The installer checks for them and stops with an error if one is missing; it does not install system packages.
- A 1Password service-account token scoped to the intended vault.
- An SSH Key item named `id_ed25519` in that vault, with a valid OpenSSH private key and matching public key suitable for unattended use.
- That public key registered to the intended GitHub account for authentication and signing, with read access to the dotfiles repository.

See [the 1Password setup procedure](skills/1password-setup/SKILL.md) for account preparation.

No model provider, Telegram bot, agent runtime, or workspace repository is required.

## Install

```bash
curl -fsSL https://berrybolt.bot/install.sh | bash
```

The installer prompts for the account name, email, GitHub handle, vault, and token, then shows a review step. For an unattended run, set every input in the environment and pass `--non-interactive`. Keep the token inside a subshell, off the command line and out of shell history:

```bash
(
  read -rsp 'Service account token: ' OP_SERVICE_ACCOUNT_TOKEN && echo
  export OP_SERVICE_ACCOUNT_TOKEN
  export CHEZMOI_AGENT_NAME="..." CHEZMOI_AGENT_EMAIL="..." \
    CHEZMOI_AGENT_HANDLE_GITHUB="..." CHEZMOI_OP_VAULT="..."
  curl -fsSL https://berrybolt.bot/install.sh | bash -s -- --non-interactive
)
```

The published `berrybolt.bot` endpoint is managed outside this repository and may serve an earlier installer until this candidate is promoted.

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
| `tests/` | Local regression checks and target-side fundamentals assertions |

## Validation

- `tests/regression.sh` — run on a development host. It needs `bash`, `git`, `ssh-keygen`, and `chezmoi`, but no credentials. It applies into a throwaway home and never touches the real one.
- `tests/assertions.sh` — run as the installed user on the Omarchy target with `CHEZMOI_AGENT_EMAIL` and `CHEZMOI_AGENT_HANDLE_GITHUB` set. It uses live 1Password and GitHub access and creates one local signed commit in a temporary repository, which it never pushes.

Acceptance testing installs a pushed candidate from the public GitHub repository on a disposable Omarchy VM. Supply `OP_SERVICE_ACCOUNT_TOKEN` through ignored local configuration and use [tests/.env.local.example](tests/.env.local.example) for the remaining input names. Actual tokens, vault/account values, VM addresses, logins, and private platform records are local operational inputs.

## License

MIT
