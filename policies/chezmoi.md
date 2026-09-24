# Chezmoi

## Purpose

Defines how this repo is managed through chezmoi, what files belong under management, and how changes are applied safely.

## Rules

- You MUST treat the local chezmoi source repo as the source of truth for this repo.
- You SHOULD use the default chezmoi source location unless you have a documented reason not to.
- You MUST use chezmoi commands for all edits (see Canonical edit commands). You MUST NOT hand-edit managed files in `$HOME`, and you MUST NOT edit files under `~/.local/share/chezmoi/` with a plain editor. Direct edits bypass chezmoi's tracking: rendered-file edits are overwritten on the next `chezmoi apply`, and source edits skip the diff/apply review loop.
- You MUST keep managed files under `home/` and operational docs under `policies/`, `runbooks/`, and `skills/`.
- You MUST use templates for values that vary by machine, agent identity, or secret source.
- You MUST source secrets from 1Password or machine-local config. You MUST NOT commit secret values.
- You MUST NOT track volatile runtime state such as logs, caches, browser profiles, session databases, device keys, pairing state, generated media, or other ephemeral files.
- You MUST NOT take over a whole file that Omarchy owns (such as `~/.bashrc`) or the user's `~/.config/mise/config.toml`. Extend them with a `modify_` script or an additive include (see below).

## Default layout

```text
~/.local/share/chezmoi/          # local chezmoi source repo
├── .chezmoiroot                 # points to home/
├── home/                        # rendered files managed by chezmoi
│   ├── .chezmoi.toml.tmpl       # config/data template (no prompts after install.sh)
│   ├── .chezmoiscripts/         # run_once_after_10 (mise tools), run_after_30 (SSH)
│   ├── modify_dot_bashrc        # additive block in Omarchy's ~/.bashrc
│   ├── dot_gitconfig.tmpl
│   ├── dot_config/              # git/, mise/conf.d/, private_op/
│   └── dot_local/               # bin/ wrappers, share/ssh-bootstrap/ pins
├── policies/
├── runbooks/
├── skills/
└── tests/
```

### Extending Omarchy-owned files

`~/.bashrc` belongs to Omarchy's defaults and the user. `home/modify_dot_bashrc` is a chezmoi [modify script](https://www.chezmoi.io/reference/target-types/#scripts): chezmoi passes the current file on stdin and writes back its stdout. The script keeps every existing byte and maintains exactly one block between `# >>> dotfiles >>>` and `# <<< dotfiles <<<`, replacing it in place when its content changes. It fails, rather than guessing, when `~/.bashrc` is missing or the markers are damaged.

mise supports layered configuration, so the bootstrap tools live in `~/.config/mise/conf.d/dotfiles.toml` and the user's `~/.config/mise/config.toml` is never written.

### `private_` prefix and directory permissions

Chezmoi's `private_` name prefix sets mode 0700 on a directory (0600 on a file). The prefix applies to the path component it sits on, so place it on the narrowest directory that needs protection. `~/.config/op/` holds the service-account token and is `dot_config/private_op/`, which renders 0700 while `~/.config` keeps Omarchy's mode.

When adding a new private subtree, put `private_` on that subtree, not on a shared parent such as `dot_config`.

## Canonical edit commands

Every edit intent has exactly one right chezmoi command. Use these instead of editing files directly.

The **Token?** column shows which commands need `OP_SERVICE_ACCOUNT_TOKEN` in the process env. Commands marked **Yes** must be invoked as `chezmoi-with-op <subcmd>` (see "Token-aware invocations" below). Everything else works as plain `chezmoi`.

| Intent                                                 | Command                                    | Token? | Opens / Effect                                       |
| ------------------------------------------------------ | ------------------------------------------ | ------ | ---------------------------------------------------- |
| Edit a persisted data value (vault, email, etc.)       | `chezmoi edit-config`                      | No     | `~/.config/chezmoi/chezmoi.toml` in `$EDITOR`        |
| Edit the prompt template that generates config         | `chezmoi edit-config-template`             | No     | `.chezmoi.toml.tmpl` in source repo                  |
| Edit a managed file's source (template or plain)       | `chezmoi edit <target>`                    | No     | The corresponding source file under `home/`          |
| Edit and immediately apply                             | `chezmoi-with-op edit --apply <target>`    | Yes    | Same + runs apply on save (apply renders templates)  |
| Add a new file to management                           | `chezmoi add <path>`                       | No     | Copies `$HOME/<path>` into the source repo           |
| Add a new file as a template                           | `chezmoi add --template <path>`            | No     | Same + marks as `.tmpl`                              |
| Re-sync out-of-band edits (non-template files only)    | `chezmoi re-add [path]`                    | No     | Updates source from target (won't touch `.tmpl`)     |
| Drop into the source repo                              | `chezmoi cd`                               | No     | Subshell in `~/.local/share/chezmoi/`                |
| Preview pending changes                                | `chezmoi-with-op diff`                     | Yes    | Renders templates to compute diff                    |
| Apply pending changes                                  | `chezmoi-with-op apply`                    | Yes    | Renders templates + runs scripts                     |
| Check for drift                                        | `chezmoi-with-op verify`                   | Yes    | Renders to check drift                               |
| View what chezmoi would generate                       | `chezmoi-with-op cat <target>`             | Yes    | Renders and prints                                   |
| Execute a template snippet                             | `chezmoi execute-template`                 | Maybe  | Yes if the snippet uses `onepasswordRead`            |
| Print config data                                      | `chezmoi data`                             | No     | Prints `[data]` from `chezmoi.toml`                  |
| Print parsed config                                    | `chezmoi dump-config`                      | No     | For debugging                                        |

### Token-aware invocations

Commands marked **Yes** render templates that call `onepasswordRead`, which requires `OP_SERVICE_ACCOUNT_TOKEN` in chezmoi's own process environment. We deliberately do NOT put the token in the parent shell env (see `policies/credentials.md`), so these commands must be invoked through a wrapper that loads the token for the duration of the chezmoi call:

```bash
chezmoi-with-op apply
chezmoi-with-op diff
chezmoi-with-op cat ~/.gitconfig
```

Do not `cat` or `diff` secret-bearing targets such as `~/.config/op/env` in logged sessions; their output contains the token.

`chezmoi-with-op` is a script at `~/.local/bin/chezmoi-with-op`. It prepends `~/.local/share/mise/shims` and `~/.local/bin` to `PATH` (so the wrapper works from stripped-PATH callers — non-login shells, git hooks, IDE task runners, cron), uses a token the caller supplied for this command or else sources `~/.config/op/env`, execs `chezmoi` with the token in env, and exits cleanly. Restoring a missing env file and rotating the token use the supplied-token form; see [runbooks/1password-service-account.md](../runbooks/1password-service-account.md). The token never touches the parent shell. `with-op` in the same directory does the same for any other command.

If you forget and run bare `chezmoi apply`, you'll see:

```
chezmoi: template: ... error calling onepasswordRead: onepassword.mode is service, but OP_SERVICE_ACCOUNT_TOKEN is not set
```

That's the signal to re-run with `chezmoi-with-op`.

### Note on `chezmoi init`

`chezmoi init` is for first-time bootstrap, run by `install.sh` with every input in the environment. The config template uses `promptStringOnce` only as a fallback, so re-running `chezmoi init` does NOT re-prompt for values already persisted in `chezmoi.toml`. To change a persisted value, use `chezmoi edit-config`.

## Edit workflows

### Rotate a persisted data value

Use when a value that came from a bootstrap prompt needs to change — updating the agent email, switching the 1Password vault, etc. The service-account token is NOT in chezmoi data; rotate it by supplying the new token to `chezmoi-with-op` (see [runbooks/1password-service-account.md](../runbooks/1password-service-account.md#rotate-the-token)).

```bash
chezmoi edit-config          # edit the value in $EDITOR          (no token)
chezmoi-with-op diff         # preview which templates will change (needs token)
chezmoi-with-op apply        # re-render dependent templates       (needs token)
```

### Change a template's content

Use when you want to change what a template produces — adding a shell alias, tweaking a git config option, updating a run_once script.

```bash
chezmoi edit ~/.gitconfig    # opens the source file                (no token)
chezmoi-with-op diff         # preview                              (needs token)
chezmoi-with-op apply        # render                               (needs token)
```

Or in one step:

```bash
chezmoi-with-op edit --apply ~/.gitconfig   # edit + apply in one shot  (needs token)
```

Then commit the source change per `policies/git.md`.

### Add a new file to management

```bash
# 1. Create or edit the file in $HOME first                        (no token)
$EDITOR ~/.new-config

# 2. Bring it under chezmoi management                              (no token)
chezmoi add ~/.new-config
# or, if the file should be a template:
chezmoi add --template ~/.new-config

# 3. Review and apply                                               (needs token)
chezmoi-with-op diff
chezmoi-with-op apply
```

### Sync out-of-band edits

If you edited a managed plain file directly in `$HOME` (e.g. a tool wrote to it), bring the change back into source:

```bash
chezmoi re-add ~/.some-config
```

`re-add` will NOT touch `.tmpl` files — for templates, use `chezmoi edit` instead and re-introduce the change in the template source.

## Template variables

Available in `.tmpl` files:

| Variable                          | Description                                |
| --------------------------------- | ------------------------------------------ |
| `{{ .agent_name }}`               | Agent display name                         |
| `{{ .agent_email }}`              | Agent email                                |
| `{{ .agent_handle_github }}`      | GitHub username                            |
| `{{ .op_vault }}`                 | 1Password vault name                       |
| `{{ .op_ssh_item }}`              | SSH Key item title or ID in that vault     |
| `{{ .chezmoi.homeDir }}`          | Home directory path                        |
| `{{ .chezmoi.arch }}`             | CPU architecture, e.g. `amd64`             |
| `{{ .chezmoi.hostname }}`         | Machine hostname                           |
| `{{ .chezmoi.username }}`         | Current OS user                            |

The 1Password service account token is NOT a chezmoi data value. It is read from the chezmoi process env at render time via `{{ env "OP_SERVICE_ACCOUNT_TOKEN" }}` in [private_env.tmpl](../home/dot_config/private_op/private_env.tmpl). See [ARCHITECTURE.md](../ARCHITECTURE.md#secrets-model) for why.

Inspect available variables:

- `chezmoi data` prints values in the `[data]` section of `chezmoi.toml` (the agent variables above).
- `chezmoi execute-template '{{ . | toJson }}'` prints the full template context, including `.chezmoi.*` built-ins.

## Platform gating

Omarchy is the only target, so templates and scripts do not branch on `.chezmoi.os`. Do not reintroduce per-OS source trees or runtime OS probes; the installer's preflight rejects other hosts before chezmoi runs. Use `chezmoi execute-template` to verify rendered output before applying.

## 1Password in templates

```text
{{ onepasswordRead "op://<vault>/<item>/<field>" }}
{{ onepasswordRead (printf "op://%s/<item>/public key" .op_vault) }}
```

Templates that call `onepasswordRead` render only through `chezmoi-with-op` (or `install.sh`). Keep secret-bearing output out of logs.

## Scripts

- Location: `home/.chezmoiscripts/`
- `run_once_after_<order>-<name>.sh.tmpl`: runs once per content hash. Embed a manifest hash when a separate file should retrigger it (script 10).
- `run_after_<order>-<name>.sh.tmpl`: runs on every apply. Use it for ensure-state work that must repair drift even when the script is unchanged (script 30).
- Scripts fail on missing dependencies, credentials, or keys; they do not skip silently.
