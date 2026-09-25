# Vision

## North star

One command turns a freshly installed Omarchy VM into the agent's complete, working workstation.

This repository is the authoritative, reproducible definition of the agent account's setup. It covers every tool, package, configuration, and service the workstation needs, with no manual steps beyond supplying credentials. Running it again converges the machine to that definition. Rebuilding a lost workstation takes a clean Omarchy VM, this repository, 1Password, and the workspace repository; runtime state is not needed.

Omarchy is the only supported target. Reuse means another agent account can run the same setup with different identity and vault values; it does not require support for other operating systems.

## Ownership

- **Platform provisioning:** the VM, the Omarchy installation and initial access, network attachment and external isolation, backups, and host recovery. The platform hands a verified VM to this repository and does not compete for guest settings.
- **This repository (the agent's setup):** reproducible guest setup and configuration synchronization. That covers packages and tools, OS maintenance, all user-level configuration (shell, terminal, desktop, theme, editor, applications), credential bootstrap from 1Password, Git, SSH, and GitHub access, runtime services, integrations, and safe resumption after a restore.
- **Workspace repository:** the agent's persona, instructions, projects, and working material.
- **Runtime state:** sessions, logs, caches, databases, and working data stay on the machine, outside Git. A rebuild does not need them: anything worth keeping is written to the workspace repository, and scheduled work records what it has handled in the external system it works on, such as a mail folder or GitHub's read status.

1Password is the secrets authority. Git stores references to secrets, never their values.

Everything the agent writes has one of four homes: setup in this repository, content in the workspace repository, secrets in 1Password, and runtime state on the machine.

## Principles

- **One command, then converge.** On a fresh Omarchy account, `install.sh` applies the complete setup once identity and credentials are supplied. Reapplying is safe and leaves no drift.
- **Everything declared.** Every tool, package, setting, and service the workstation relies on comes from this repository. Nothing on the workstation should need manual installation or configuration to be restored.
- **Captured both ways.** The agent's own setting choices count like the owner's. A change made here is applied to the machine. A setting the agent changes on the live machine is captured here in the same session, before a reapply would revert it. Only choices are captured, never runtime state.
- **Build on Omarchy.** Use Omarchy's package conventions and its supported commands where they exist (for example, its theme and font setters). Manage files this repository owns outright. Extend files that Omarchy or other tools also write, so their updates keep working.
- **Full guest authority.** The agent administers its own VM, including system packages and services. Installs declared here run through the package manager, not ad hoc.
- **Scoped credentials.** Tokens reach only the process that needs them. Nothing secret is committed.
- **Fail clearly.** Required steps succeed or stop with an actionable error; no silent skips or protocol fallbacks.
- **Safe resumption.** When managed services exist, a restored workstation starts with outbound automation paused until pending work has been checked against external services.

## Delivery

The setup arrives in increments, each validated on a disposable Omarchy VM before it is relied on. `README.md` and `ARCHITECTURE.md` describe what is implemented today; the ignored local `PLAN.md` (when present) tracks sequencing and evidence.

## Success criteria

- A clean Omarchy VM, one command, and the agent's credentials produce the complete working workstation with no manual steps.
- Reapply converges with no managed-file drift and without breaking Omarchy's own updates.
- Credentials stay scoped; the service-account token never enters the parent shell environment.
- The agent can use Git, SSH, and GitHub as itself and produce verifiable signed commits.
- After a loss, handing a clean VM to this repository reproduces the setup, and nothing needs restoring beyond the workspace repository and the agent's sign-ins.
