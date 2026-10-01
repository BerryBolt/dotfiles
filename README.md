# Dotfiles

The agent's Omarchy workstation setup, managed with chezmoi: one command from a fresh Omarchy install to the complete, working account. It is delivered in increments; today it covers the fundamentals: Bash integration, scoped 1Password access, Git/SSH, mail, the Codex and Claude Code CLIs, the Hermes agent harness with its settings and Telegram gateway, the workspace checkout, and repeatable configuration. See [VISION.md](VISION.md) for the full scope.

**Status:** fresh install, repeat install, reapply, recovery, login, and restart checks pass on a disposable Omarchy 4.0.4 (x86_64) VM.

Read [VISION.md](VISION.md) for scope and [ARCHITECTURE.md](ARCHITECTURE.md) for the bootstrap flow, managed state, and recovery contract.

## Prerequisites

- An installed Omarchy workstation and the intended user account, provided by the platform owner. Run the installer as that user, not root.
- Omarchy's default Bash, Git, OpenSSH, and mise. The installer checks for them and stops with an error if one is missing.
- A 1Password service-account token scoped to the intended vault, with read and write item permissions there. The agent has no 1Password user account; see the [access model](policies/credentials.md#access-model).
- An SSH Key item in that vault, with a valid OpenSSH private key and matching public key suitable for unattended use. The installer selects it by title or item ID (`CHEZMOI_OP_SSH_ITEM`); an ID keeps working if the item is renamed. It is always installed as `~/.ssh/id_ed25519`, whatever the item is called.
- That public key registered to the intended GitHub account for authentication and signing, with read access to the dotfiles repository.
- The agent's workspace repository on GitHub, readable by that account. The installer takes it as `owner/name` (`CHEZMOI_AGENT_WORKSPACE_REPO`) and clones it into `~/brain`.
- A `Purelymail` Login item in that vault with the agent's mailbox address (`username`) and password. Mail is configured from it.
- A Server item in that vault with the account's OS login: `username` (the installing account) and `password`. The installer selects it by title or item ID (`CHEZMOI_OP_ACCOUNT_ITEM`). Setup pipes the password to sudo once to grant the account passwordless sudo, because the agent administers its own VM unattended.
- A `Claude Code - OAuth token` API Credential item in that vault, holding a token the subscription owner created with `claude setup-token`. Apply writes it into Claude Code's settings.
- A `Telegram Bot - API key` API Credential item in that vault, with the bot token (`credential`) and the owner's Telegram user ID (`owner user ID`). Apply writes both into Hermes' settings.
- A `Brave Search - API key` API Credential item in that vault, with a Brave Search API key (`credential`). Hermes uses it for web search.

See [the 1Password setup procedure](skills/1password-setup/SKILL.md) for account preparation.

Claude Code works from the token item. Codex needs two device logins that 1Password cannot hold, one for the CLI and one for Hermes: an attended install signs in whichever is missing and the owner approves each code with the ChatGPT subscription; an unattended install names the missing ones (see [Runtime sign-ins](policies/credentials.md#runtime-sign-ins)).

## Install

```bash
curl -fsSL https://berrybolt.bot/install.sh | bash
```

The installer prompts for missing inputs, then shows a review step. On a rerun, it reuses identity, vault, and item selectors from chezmoi configuration, the token from `~/.config/op/env`, and the workspace repository from `~/brain`'s GitHub SSH origin. Environment overrides take precedence. If a device login expires, rerun the same install command and approve the new code; earlier setup stays applied.

For an unattended fresh install, set every input in the environment and pass `--non-interactive`. An unattended rerun can reuse saved inputs; it fails if any are missing. Keep the token inside a subshell, off the command line and out of shell history:

```bash
(
  read -rsp 'Service account token: ' OP_SERVICE_ACCOUNT_TOKEN && echo
  export OP_SERVICE_ACCOUNT_TOKEN
  export CHEZMOI_AGENT_NAME="..." CHEZMOI_AGENT_EMAIL="..." \
    CHEZMOI_AGENT_HANDLE_GITHUB="..." CHEZMOI_AGENT_WORKSPACE_REPO="owner/name" \
    CHEZMOI_OP_VAULT="..." CHEZMOI_OP_SSH_ITEM="..." CHEZMOI_OP_ACCOUNT_ITEM="..."
  curl -fsSL https://berrybolt.bot/install.sh | bash -s -- --non-interactive
)
```

`https://berrybolt.bot/install.sh` redirects to `install.sh` on this repository's `main` branch.

The source comes from `https://github.com/<GitHub handle>/dotfiles.git`, on its default branch unless you pin a revision.

After the apply has restored the SSH key, the installer clones the workspace repository into `~/brain` over SSH. When `~/brain` is already a checkout, it leaves it as is.

An install run from a terminal ends with Omarchy's own update, `omarchy-update`, the one Omarchy's first-run notification offers. It asks before it starts and may offer a reboot when it finishes; the setup is already applied by then. A `--non-interactive` run, or one without a terminal, leaves the update for you to run.

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
git -C ~/brain pull          # the workspace checkout, cloned by the installer
git commit -S ...            # commits are signed by default
sudo -n true                 # the account has passwordless sudo
himalaya envelope list       # the agent's inbox (password read from 1Password per connection)
codex login --device-auth    # when not signed in (an attended install runs it); the owner approves the code
codex exec "..."             # GPT-6 Luna on high, on the ChatGPT login only
claude -p "..."              # Opus 5.5 on the subscription token
hermes auth add openai-codex --type oauth  # when not signed in (an attended install runs it): Hermes' own Codex login
hermes -z "..."               # GPT-6 Luna through Hermes' own sign-in, at the release pinned in apply script 50
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
| `tests/` | Acceptance checks run on the installed Omarchy account |

## Validation

- `tests/assertions.sh` — run as the installed user on the Omarchy target with `CHEZMOI_AGENT_EMAIL`, `CHEZMOI_AGENT_HANDLE_GITHUB`, and `CHEZMOI_AGENT_WORKSPACE_REPO` set. It uses live 1Password and GitHub access and creates one local signed commit in a temporary repository, which it never pushes. It makes one short model call each through Codex and Claude Code, so Codex must be signed in.
- `tests/recovery.sh` — **destructive; disposable or test accounts only.** It deletes and restores the SSH key, the passwordless sudo rule, and the credential env file, and simulates a rotated key with a generated fixture key. It reads the token from stdin for the env-file restore. The live 1Password item and GitHub registration are not changed.

Acceptance testing installs a pushed candidate from the public GitHub repository on a disposable Omarchy VM. Supply `OP_SERVICE_ACCOUNT_TOKEN` through ignored local configuration and use [tests/.env.local.example](tests/.env.local.example) for the remaining input names. Actual tokens, vault/account values, VM addresses, logins, and private platform records are local operational inputs.

## License

MIT
