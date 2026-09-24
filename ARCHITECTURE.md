# Architecture

[Vision](VISION.md) defines an Omarchy-only workstation baseline, independent of agent harnesses. The ignored local `PLAN.md` (when present) tracks implementation tasks and validation evidence.

## Responsibility boundaries

| Layer | Owner | Responsibility |
| --- | --- | --- |
| VM and OS | Platform provisioning / Omarchy | Provisioning, desktop, accounts, administrative rights, private access, isolation, platform restart behavior |
| User bootstrap | This repo | Chezmoi, scoped 1Password access, Bash integration, Git identity/signing, SSH restore and trust |
| Agent execution | Future harness/workspace setup | Provider authentication, runtime services, workspace placement, integrations, identity, memory, behavior |

Omarchy is the sole deployment target. The bootstrap preserves its Bash initialization and unrelated mise settings. A development host can run the isolated regression tests without being a supported installation target.

## Chezmoi source model

- `.chezmoiroot` selects `home/` as the managed source root.
- The default checkout is `~/.local/share/chezmoi`; user configuration is rendered into the home directory.
- Policies, runbooks, skills, and tests stay in the source repository and are not applied.
- Account name, email, GitHub handle, vault name, and the SSH key item selector (`op_ssh_item`, a title or item ID) are chezmoi data. The service-account token is never persisted in chezmoi data or committed source.
- Source updates and target applies are separate operations. Review source changes, then apply them with the required credential context.

Use chezmoi commands for managed-file changes per [policies/chezmoi.md](policies/chezmoi.md). Isolate development rendering and testing from the operator's real home directory.

## Bootstrap flow

1. **Preflight.** `install.sh` requires Omarchy (`ID=omarchy` in `/etc/os-release`), a non-root user, `git`, `ssh`, `ssh-keygen`, `mise`, and an existing `~/.bashrc`. Omarchy supplies all of them. A missing prerequisite stops the installer before it changes anything; it never installs system packages.
2. **Inputs.** It collects the account name, email, GitHub handle, vault, SSH key item, and service-account token from the environment or prompts. `--non-interactive` requires every input from the environment. The token is never displayed.
3. **Bootstrap tools.** It installs `chezmoi` and the 1Password CLI with mise in user space, then verifies that the token belongs to a service account, the vault is accessible, and the SSH key item is readable. Bad credentials fail here, before any configuration is written.
4. **Source.** On first install it clones `https://github.com/<handle>/dotfiles.git` over HTTPS. On later runs it requires the SSH remote configured by the first apply, refuses a source with local modifications, and fast-forwards over SSH. It never falls back to HTTPS. With `--revision <full-sha>` it detaches the source at exactly that commit instead, fetching it from `origin` when needed, and fails if the commit cannot be obtained. The installer logs the applied commit.
5. **Apply.** `chezmoi init --apply` renders the config from the collected inputs (no further prompts), persists non-secret data, and applies the managed files and scripts below.

Bootstrap does not install agent CLIs, start an agent service, clone an agent workspace, select a model, or create a first-wake file.

## Managed state

| Target | Source | Behavior |
| --- | --- | --- |
| `~/.bashrc` | `home/modify_dot_bashrc` | Keeps Omarchy's file byte-for-byte and maintains one marked block that defines `op()` as `with-op op`. Fails if the file is missing or the block markers are damaged. |
| `~/.local/bin/with-op` | `home/dot_local/bin/executable_with-op` | Runs one command with `~/.config/op/env` loaded into that process only. |
| `~/.local/bin/chezmoi-with-op` | `home/dot_local/bin/executable_chezmoi-with-op` | Runs chezmoi with the token loaded for template rendering. |
| `~/.config/op/env` | `home/dot_config/private_op/private_env.tmpl` | Token, vault, and `OP_FORMAT=json`; mode 0600 in a 0700 directory. `~/.config` keeps Omarchy's mode. |
| `~/.config/mise/conf.d/dotfiles.toml` | `home/dot_config/mise/conf.d/dotfiles.toml` | Declares `chezmoi` and `1password-cli`. `~/.config/mise/config.toml` stays user-owned. |
| `~/.gitconfig` | `home/dot_gitconfig.tmpl` | Identity and SSH commit/tag signing with `~/.ssh/id_ed25519`. Omarchy's `~/.config/git/config` still applies underneath. |
| `~/.config/git/allowed_signers` | `home/dot_config/git/allowed_signers.tmpl` | Agent email and the public key of the `op_ssh_item` item. |
| `~/.local/share/ssh-bootstrap/` | `home/dot_local/share/ssh-bootstrap/` | GitHub host keys and fingerprints pinned from GitHub's documentation. |
| Script 10 | `run_once_after_10-install-mise-tools.sh.tmpl` | Installs the manifest's tools; reruns when the manifest hash changes. |
| Script 30 | `run_after_30-restore-ssh-key.sh.tmpl` | Restores or validates `~/.ssh/id_ed25519` against the `op_ssh_item` item, refreshes pinned GitHub `known_hosts` entries, and switches an HTTPS GitHub source remote to SSH. |

In Omarchy's interactive Bash, `op`, `with-op`, and `chezmoi-with-op` are available. Omarchy puts `~/.local/bin` and the mise shims on `PATH` for login and SSH shells; both wrappers also prepend those directories themselves for stripped-`PATH` callers. Non-interactive callers use `with-op op ...` because the `op()` function exists only in interactive shells.

## Secrets model

1Password remains the source of truth. `~/.config/op/env` is the local service-account environment file. SSH private key material lives under `~/.ssh` with directory mode 0700 and key mode 0600. These are explicit local secret-materialization locations; secrets do not exist only in the env file.

Credential wrappers load the env only into the child process that needs it. Bash startup does not export the token into the parent shell. Rendering obtains the token from the invoking process; the templates reject an absent token rather than replace stored credentials with an empty value.

Pinned GitHub host keys establish trust before authenticated Git operations. Git's allowed signers follow the public key from 1Password. Both key consumers resolve the same `op_ssh_item` selector; the local filename `~/.ssh/id_ed25519` does not depend on the item's title. Key restoration preserves the relationship between the signing key and allowed signers: chezmoi renders `allowed_signers` before the `run_after_` script aligns the private key.

## Apply scripts

Keep install steps distinct from state restoration:

- `run_once_after_` suits installs tied to a manifest. Script 10 embeds the manifest hash so changes to that separate file retrigger installation.
- `run_after_` is required for SSH state that must be restored even when the script content has not changed.
- Required dependency, credential, key, and authentication failures stop the operation.

Do not turn these scripts into general repair orchestration. Package managers own reinstalling missing tool binaries.

## Recovery

The retained scope is:

- Restore a missing SSH private key from 1Password through reapply.
- Detect a rotated key and align signing verification with the replacement. Script 30 currently moves the on-disk key aside as `~/.ssh/id_ed25519.stale.<timestamp>` before it fetches the replacement.
- Restore `~/.config/op/env` when the caller explicitly supplies a valid token. **Pending:** `chezmoi-with-op` still refuses to run when the env file is missing.

Use local `chezmoi-with-op apply` for key recovery before attempting SSH source synchronization. `install.sh` pulls an existing source before apply and cannot be the repair path for missing SSH credentials. Tool reinstall, workspace restoration, runtime data backup, and general broken-machine recovery are outside this contract.

## Validation

- `tests/regression.sh` runs on a development host without credentials or a target machine. It applies the source into a throwaway home with a fake `op` and fixture keys and checks unattended init, preservation of existing Bash and mise content, reapply drift, wrapper scoping, revision selection, and SSH restoration.
- `tests/assertions.sh` runs on the installed Omarchy account with live 1Password and GitHub access. It checks the Bash integration, credential scope and permissions, identity and local commit signing, key and host trust, and managed-file drift.

Acceptance happens on a disposable Omarchy VM that installs a pushed candidate from the public GitHub repository: the installer is downloaded from `raw.githubusercontent.com/.../<sha>/install.sh` and run with `--revision <sha>`, so the installer and the applied source are the same commit on fresh and repeat installs. Fixture success is not Omarchy or live-credential evidence. Machine access and private operational context stay in ignored local inputs.

## Invariants

1. Omarchy is the only installation target; unsupported hosts fail before mutation.
2. Preserve Omarchy shell initialization, desktop configuration, and unrelated user/tool settings.
3. Keep secrets out of Git and out of the parent interactive shell environment.
4. Every required bootstrap step either succeeds or exits with a clear error.
5. After installer input collection, template rendering and apply do not introduce further prompts.
6. Reapply is safe and does not require a harness, provider, integration, or workspace repository.
7. SSH restoration remains an ensure-state operation; source sync does not fall back to HTTPS.
8. Removing source management does not authorize deleting existing user data, uninstalling tools, or destroying a workspace.
9. Completion requires evidence for the workstation fundamentals; package presence alone is insufficient.
