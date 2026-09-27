# Architecture

[Vision](VISION.md) defines this repository as the agent's complete, one-command Omarchy workstation setup, delivered in increments. This document describes what is implemented now. The ignored local `PLAN.md` (when present) tracks the next increments and validation evidence.

## Responsibility boundaries

| Layer | Owner | Responsibility |
| --- | --- | --- |
| VM and platform | Platform provisioning | VM, Omarchy installation and initial access, network attachment and isolation, backups, host recovery |
| Workstation setup | This repo | Packages and tools, OS maintenance, all user-level configuration, credential bootstrap, Git/SSH/GitHub access, runtime services, integrations, safe resumption |
| Agent content | Workspace repo | Persona, instructions, projects, working material |
| Secrets | 1Password | Credentials and private values; Git holds only references |
| Runtime state | The machine only | Sessions, logs, caches, databases, working data; never in Git, and not needed to rebuild |

Everything the agent writes belongs to one of the last four layers. Setup is captured both ways: a change made in this repository is applied, and a setting the agent changes on the live machine is captured back here before the next reapply would revert it. A whole file is captured with `chezmoi re-add`, and a file another program also writes by adding the chosen keys to the declared ones. Runtime state is never captured; what is worth keeping is written to the workspace repository.

Omarchy is the sole deployment target. The setup builds on Omarchy's defaults: it preserves Bash initialization and the user's mise settings, and extends files that Omarchy also writes.

### Implemented so far

The current increment covers the workstation fundamentals: prerequisite checks, chezmoi, scoped 1Password access, Bash integration, Git identity and signing, SSH key restore and GitHub host trust, passwordless sudo for the agent account, system packages (Brave as the default browser), mail through `himalaya`, the Codex and Claude Code CLIs with their settings, the Hermes agent harness at a pinned release with its model, tool, and Telegram settings and its gateway service, the workspace checkout, revision-pinned installs, and the recovery paths below. Desktop, terminal, and theme settings; Hermes' brain wiring and other services; and further integrations belong to this repository but are not implemented yet.

## Chezmoi source model

- `.chezmoiroot` selects `home/` as the managed source root.
- The default checkout is `~/.local/share/chezmoi`; user configuration is rendered into the home directory.
- Policies, runbooks, skills, and tests stay in the source repository and are not applied.
- Account name, email, GitHub handle, vault name, and the item selectors for the SSH key (`op_ssh_item`) and the workstation account (`op_account_item`), each a title or item ID, are chezmoi data. The service-account token is never persisted in chezmoi data or committed source. The workspace repository is an installer input only; apply never reads it.
- Source updates and target applies are separate operations. Review source changes, then apply them with the required credential context.

Use chezmoi commands for managed-file changes per [policies/chezmoi.md](policies/chezmoi.md). Isolate development rendering and testing from the operator's real home directory.

## Bootstrap flow

1. **Preflight.** `install.sh` requires Omarchy (`ID=omarchy` in `/etc/os-release`), a non-root user, `git`, `ssh`, `ssh-keygen`, `mise`, and an existing `~/.bashrc`. Omarchy supplies all of them. A missing prerequisite stops the installer before it changes anything. The installer itself never installs system packages; apply script 40 does, once sudo is passwordless, and Omarchy's update (step 7) upgrades them.
2. **Inputs.** It collects the account name, email, GitHub handle, workspace repository (`owner/name`), vault, SSH key item, workstation account item, and service-account token from the environment or prompts. `--non-interactive` requires every input from the environment. The token is never displayed.
3. **Bootstrap tools.** It installs `chezmoi` and the 1Password CLI (the tools the first render needs) with mise in user space, then verifies that the token belongs to a service account, the vault is accessible, the SSH key item is readable, and the workstation account item names the installing account. While sudo still asks for a password, it also checks the item's password against sudo. Bad credentials fail here, before any configuration is written.
4. **Source.** On first install it clones `https://github.com/<handle>/dotfiles.git` over HTTPS. On later runs it requires the SSH remote configured by the first apply, refuses a source with local modifications, and fast-forwards over SSH. It never falls back to HTTPS. With `--revision <full-sha>` it detaches the source at exactly that commit instead, fetching it from `origin` when needed, and fails if the commit cannot be obtained. The installer logs the applied commit.
5. **Apply.** `chezmoi init --apply` renders the config from the collected inputs (no further prompts), persists non-secret data, and applies the managed files and scripts below.
6. **Workspace.** Once apply has restored the SSH key and pinned GitHub's host keys, the installer clones `git@github.com:<owner/name>.git` into `~/brain`. An existing checkout there belongs to the agent and is left as is; anything else at that path stops the installer. A failed clone stops it with an error, and rerunning the installer retries the clone.
7. **Omarchy update.** When a person is at the terminal (no `--non-interactive`, a TTY present), the installer finishes with `omarchy-update`, the update Omarchy's first-run notification offers, reading answers from the terminal. It asks before it starts and may offer to remove orphaned packages or to reboot; those prompts ignore `-y` in Omarchy 4.0.4 and never return without a person, so an unattended run leaves the update to the operator and says so. The update runs in Omarchy's environment (its `env-bootstrap` sets `OMARCHY_PATH`) and without the service-account token. A failed update stops the installer with an error.

Apply starts one service, the Hermes gateway, and configures no integrations beyond mail, the agent CLIs, and Hermes' Telegram channel. Others arrive as later increments of this repository. The workspace clone and the Omarchy update are installer steps, not part of apply: reapply never reads or changes `~/brain` and never updates Omarchy, and runtime state is not restored.

## Managed state

| Target | Source | Behavior |
| --- | --- | --- |
| `~/.bashrc` | `home/modify_dot_bashrc` | Keeps Omarchy's file byte-for-byte and maintains one marked block that defines `op()` as `with-op op`. Fails if the file is missing or the block markers are damaged. |
| `~/.local/bin/with-op` | `home/dot_local/bin/executable_with-op` | Runs one command with `~/.config/op/env` loaded into that process only. |
| `~/.local/bin/chezmoi-with-op` | `home/dot_local/bin/executable_chezmoi-with-op` | Runs chezmoi with the token for template rendering: a token supplied in the caller's environment wins, otherwise `~/.config/op/env`; with neither it fails. |
| `~/.config/op/env` | `home/dot_config/private_op/private_env.tmpl` | Token, vault, and `OP_FORMAT=json`; mode 0600 in a 0700 directory. `~/.config` keeps Omarchy's mode. |
| `~/.config/mise/conf.d/dotfiles.toml` | `home/dot_config/mise/conf.d/dotfiles.toml` | Declares the tools Omarchy does not provide: `chezmoi`, `1password-cli`, and `wrangler` (npm backend, on Omarchy's Node). `~/.config/mise/config.toml` stays user-owned. Tools Omarchy provides, such as `gh`, come from its on-demand launchers. |
| `~/.gitconfig` | `home/dot_gitconfig.tmpl` | Identity and SSH commit/tag signing with `~/.ssh/id_ed25519`. Omarchy's `~/.config/git/config` still applies underneath. |
| `~/.config/git/allowed_signers` | `home/dot_config/git/allowed_signers.tmpl` | Agent email and the public key of the `op_ssh_item` item. |
| `~/.config/himalaya/config.toml` | `home/dot_config/himalaya/config.toml.tmpl` | The agent's Purelymail mailbox over IMAP and SMTP with TLS. The address comes from the `Purelymail` item at render time; `himalaya` reads the password through `with-op` on each connection, so the file holds none. |
| `~/.codex/config.toml` | `home/dot_codex/modify_config.toml` | Merged: sets the model (`gpt-6-luna`), high reasoning effort, the ChatGPT login as the only login method, and file credential storage in `~/.codex/auth.json`. Keeps every key Codex writes itself, such as model picks, notices, and project trust. |
| `~/.claude/settings.json` | `home/dot_claude/modify_private_settings.json` | Merged, mode 0600: turns off Claude Code's commit and PR attribution, sets the default model to Opus 5.5 (`claude-opus-5-5`), and sets `env.CLAUDE_CODE_OAUTH_TOKEN` from the `Claude Code - OAuth token` item. Keeps every other key Claude Code writes itself, such as `/config` choices; a `/model` pick lasts until the next apply. |
| `~/.claude.json` | `home/modify_private_dot_claude.json` | Claude Code's runtime state, mode 0600. Sets `hasCompletedOnboarding`, so interactive `claude` skips first-run onboarding and signs in with the token; once the key is set, the file passes through unchanged. |
| `~/.hermes/config.yaml` | `home/private_dot_hermes/modify_private_config.yaml` | Merged, mode 0600: Hermes' own Codex sign-in to GPT-6 Luna on high effort, 150 turns, never borrowing the Codex CLI's login, Hermes' memory and update check off, the tools for the CLI and for Telegram (Telegram without session search), image generation through Codex, web search through Brave's free plan, and the local browser. Keeps every key Hermes writes itself. When every declared key already has its value, the file passes through byte for byte; otherwise it is rewritten, which drops the comments from Hermes' template and sorts the keys. |
| `~/.hermes/.env` | `home/private_dot_hermes/modify_private_dot_env` | Merged, mode 0600: the Telegram bot token, and the owner's Telegram user ID as the only allowed user and the home chat, from the `Telegram Bot - API key` item; the Brave Search API key from the `Brave Search - API key` item. Keeps every other line. |
| `~/.config/systemd/user/hermes-gateway.service.d/dotfiles.conf` | `home/dot_config/systemd/user/hermes-gateway.service.d/dotfiles.conf` | A drop-in for the gateway unit that Hermes generates: unsets `CODEX_API_KEY` and `OPENAI_API_KEY`, so Codex in the gateway stays on the ChatGPT login. Hermes rewrites its own unit when it is outdated; the drop-in survives that. |
| `~/.ssh/config` | `home/private_dot_ssh/modify_private_config` | Keeps the user's entries and maintains one marked block at the top: `github.com` uses only `~/.ssh/id_ed25519` (`IdentitiesOnly`), so keys in a forwarded or local SSH agent are never offered to GitHub. File 0600, directory 0700. |
| `~/.local/share/ssh-bootstrap/` | `home/dot_local/share/ssh-bootstrap/` | GitHub host keys and fingerprints pinned from GitHub's documentation. |
| Script 10 | `run_once_after_10-install-mise-tools.sh.tmpl` | Installs the tools named in the manifest (read at render time); reruns when the manifest hash changes. |
| Script 20 | `run_after_20-passwordless-sudo.sh.tmpl` | Ensures `/etc/sudoers.d/05-dotfiles-nopasswd` (root:root 0440) grants the account `NOPASSWD: ALL`, with `verifypw=any` so `sudo -v` also passes without a password (Omarchy's installer rule for the account is not `NOPASSWD`, and `omarchy-update` runs `sudo -v`). While sudo still asks for a password, it pipes the `op_account_item` password to `sudo -S` to install the rule, validating it with `visudo` before it takes effect. It fails if sudo or `sudo -v` still needs a password afterwards. The file sorts after the installer's per-user rule and before Omarchy's narrower rules. |
| Script 30 | `run_after_30-restore-ssh-key.sh.tmpl` | Restores or validates `~/.ssh/id_ed25519` against the `op_ssh_item` item, refreshes pinned GitHub `known_hosts` entries, and switches an HTTPS GitHub source remote to SSH. |
| Script 40 | `run_once_after_40-install-system-packages.sh` | Installs system packages with Omarchy's commands: `himalaya` from Arch's repositories, and Brave through `omarchy-install-browser` (AUR, Omarchy's flags and theme policy), then makes it the default browser. Reruns when the script changes. |
| Script 50 | `run_once_before_50-install-hermes.sh` | Installs Hermes Agent with Hermes' own installer at the commit pinned in the script: a git checkout in `~/.hermes/hermes-agent` with its own Python environment, and the `hermes` command in `~/.local/bin`. Runs only the installer's unattended stages, so it never starts the setup wizard or offers the gateway service, and fails unless the checkout ends at the pin. Runs before files are applied, so the installer has seeded `~/.hermes/config.yaml` and `.env` for the templates that extend them. Reruns when the script changes. |
| Script 60 | `run_onchange_after_60-hermes-gateway.sh.tmpl` | Installs the Hermes gateway as Hermes' own systemd user service (`hermes gateway install`) when it is missing, enables it, and ensures lingering, so it runs without a login and starts at boot. A new service starts paused (see [Safe resumption](#safe-resumption)); a running one is restarted gracefully in the background, after its turns in progress, so it loads what changed. Runs again when Hermes' install script, its settings templates, their 1Password values, or the drop-in change. |

`codex` and `claude` come from Omarchy's on-demand launchers, which install them through mise on first use; this repository declares only their settings. Both settings files are extended rather than owned because each CLI also writes its own choices there: the merge templates set the declared keys and keep the rest. `~/.claude.json` is Claude Code's runtime state, which it rewrites on every launch; its template adds only the onboarding flag and otherwise leaves the file byte for byte.

Hermes comes from its own installer rather than Omarchy's route ([dependencies](policies/dependencies.md)). The installer uses Omarchy's Node and tools, finds `~/.local/bin` already on `PATH`, and so leaves shell startup files and system packages alone. When they are missing, it seeds `~/.hermes/config.yaml`, `.env`, and `SOUL.md` from its templates. Apply then sets the declared keys in `config.yaml` and `.env`; `SOUL.md` is not managed yet. Hermes reads its configuration when it starts; script 60 restarts the gateway when the declared settings or their values change.

In Omarchy's interactive Bash, `op`, `with-op`, and `chezmoi-with-op` are available. Omarchy puts `~/.local/bin` and the mise shims on `PATH` for login and SSH shells; both wrappers also prepend those directories themselves for stripped-`PATH` callers. Non-interactive callers use `with-op op ...` because the `op()` function exists only in interactive shells.

## Secrets model

1Password remains the source of truth. The agent's only 1Password identity is its service account, with read and write item permissions in its vault ([access model](policies/credentials.md#access-model)). `~/.config/op/env` is the local service-account environment file. SSH private key material lives under `~/.ssh` with directory mode 0700 and key mode 0600. Claude Code's subscription token lives in `~/.claude/settings.json` (0600), where `claude` reads it whoever starts it ([Claude Code](policies/credentials.md#claude-code)). The Telegram bot token and the Brave Search API key live in `~/.hermes/.env` (0600), where Hermes reads them ([Hermes](policies/credentials.md#hermes)). These are explicit local secret-materialization locations; secrets do not exist only in the env file.

Credential wrappers load the env only into the child process that needs it. Bash startup does not export the token into the parent shell. Rendering obtains the token from the invoking process; the templates reject an absent token rather than replace stored credentials with an empty value.

Pinned GitHub host keys establish trust before authenticated Git operations. GitHub SSH uses the default `github.com:22` and needs outbound port 22; the platform owns that egress. There is no fallback to another port or to HTTPS. GitHub SSH offers only the restored key, so a session that forwards someone else's SSH agent cannot make the agent act as another GitHub account. Git's allowed signers follow the public key from 1Password. Both key consumers resolve the same `op_ssh_item` selector; the local filename `~/.ssh/id_ed25519` does not depend on the item's title. Key restoration preserves the relationship between the signing key and allowed signers: chezmoi renders `allowed_signers` before the `run_after_` script aligns the private key.

## Apply scripts

Keep install steps distinct from state restoration:

- `run_once_after_` suits installs tied to a manifest. Script 10 embeds the manifest hash so changes to that separate file retrigger installation. Script 50 keeps its pin in the script itself, so changing the pin reruns it; it is a `run_once_before_` script because the files it creates are extended by managed templates.
- `run_onchange_after_` runs when its rendered content changes. Script 60 embeds the hashes of the files and 1Password values the gateway loads, so it runs, and restarts the gateway, when any of them changes.
- `run_after_` is required for SSH and sudo state that must be restored even when the script content has not changed.
- Required dependency, credential, key, and authentication failures stop the operation.

Do not turn these scripts into general repair orchestration. Package managers own reinstalling missing tool binaries.

## Recovery

The retained scope is:

- Restore a missing SSH private key from 1Password through reapply.
- Detect a rotated key, preserve the previous key until the replacement is verified, and align signing verification with the replacement. Script 30 fetches the new private key to a temporary file and checks that it derives the item's public key. Only then does it move the old key to `~/.ssh/id_ed25519.stale.<timestamp>` and install the new one. A bad or mismatched item fails and leaves the current key in place. `allowed_signers` is re-rendered from the same item in the same apply.
- Restore a missing or altered passwordless sudo rule through reapply. Script 20 uses the account password from 1Password only in that case; while the rule works, sudo needs neither 1Password nor the password.
- Restore `~/.config/op/env` when the caller explicitly supplies a valid token: `OP_SERVICE_ACCOUNT_TOKEN=... chezmoi-with-op apply --force ~/.config/op/env`. A supplied token takes precedence over the file, so after a token rotation a plain `chezmoi-with-op apply` with the new token re-renders the file instead of reusing the old value. Without a supplied token and without the file, `chezmoi-with-op` and `with-op` fail with the restore command. `--force` is needed only because chezmoi treats a deleted managed file as a local change and would otherwise ask before recreating it; naming the single target keeps the override narrow.

Use local `chezmoi-with-op apply` for key recovery before attempting SSH source synchronization. `install.sh` pulls an existing source before apply and cannot be the repair path for missing SSH credentials. Tool reinstall, workspace restoration, runtime data backup, and general broken-machine recovery are outside this contract.

## Safe resumption

A new workstation's Hermes gateway starts paused. Before script 60 installs the service, it runs `hermes pause`, which writes `~/.hermes/ESTOP`: the gateway connects to Telegram but takes no new turns and runs no cron jobs. Check pending work against the systems the agent works in, then run `hermes resume`. Reapply on a workstation whose gateway is already installed never pauses it.

## Validation

- `tests/assertions.sh` runs on the installed Omarchy account with live 1Password and GitHub access. It checks the Bash integration (interactive and login shells), passwordless sudo, system packages and tools, mail login (IMAP, and SMTP with a `NOOP` that sends nothing), the agent CLIs (Claude Code's settings and their 0600 mode, its onboarding flag, and one live call each that proves the Codex ChatGPT login and that Claude Code finds its token with none in the environment and answers on its default model), the Hermes install (its own launcher, the checkout at the pin, a completed installer run, untouched shell startup files, 0600 settings files, its own Codex sign-in, one live call that answers on GPT-6 Luna through the subscription, a live Telegram bot token, a Brave Search key that answers one query, and the gateway service: enabled and running with the drop-in and lingering, at the pin, and connected to Telegram), credential scope and permissions, identity and local commit signing, key and host trust (GitHub SSH offers only the agent's key), SSH source sync, managed-file drift, and the workspace checkout's origin and SSH access.
- `tests/recovery.sh` runs on a disposable installed account. It proves the recovery paths above: a deleted key, a previous (fixture) key being replaced, a deleted sudo rule restored with the account password from 1Password, and a deleted env file restored from a token supplied on stdin.

Acceptance happens on a disposable Omarchy VM that installs a pushed candidate from the public GitHub repository: the installer is downloaded from `raw.githubusercontent.com/.../<sha>/install.sh` and run with `--revision <sha>`, so the installer and the applied source are the same commit on fresh and repeat installs. Machine access and private operational context stay in ignored local inputs.

## Invariants

1. Omarchy is the only installation target; unsupported hosts fail before mutation.
2. Build on Omarchy: keep its shell initialization and updates working, prefer its supported commands, and extend files it or other tools also write. Only files listed in Managed state are owned outright.
3. Keep secrets out of Git and out of the parent interactive shell environment.
4. Every required bootstrap step either succeeds or exits with a clear error.
5. After installer input collection, template rendering and apply do not introduce further prompts. The only later prompts are Omarchy's own, from the update that ends an attended install.
6. Reapply is safe, converges without drift, and does not depend on the workspace repository or on runtime state.
7. SSH restoration remains an ensure-state operation; source sync does not fall back to HTTPS.
8. Removing source management does not authorize deleting existing user data, uninstalling tools, or destroying a workspace.
9. Completion requires evidence for the workstation fundamentals; package presence alone is insufficient.
