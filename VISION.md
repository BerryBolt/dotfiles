# Vision

## North star

Prepare a usable, reproducible Omarchy workstation for an agent account, independent of which agent harness may be selected later.

Omarchy is the only supported target. Reuse means another account or machine can use the same fundamentals with different identity and vault values; it does not require support for other operating systems.

## Bootstrap outcome

Starting from an installed Omarchy desktop and the intended user account:

1. Check the required shell, package, Git, and OpenSSH prerequisites.
2. Establish chezmoi management and scoped 1Password service-account access.
3. Restore the account's SSH key and configure Git identity, signing, and GitHub host trust.
4. Make those capabilities available in Omarchy's normal Bash terminal.
5. Prove that managed configuration can be reapplied and the documented credential/key recovery paths work.

Bootstrap ends when the user can use the workstation's fundamentals. An authenticated agent conversation, background agent service, or first-wake file is not an acceptance condition.

## Ownership

- **Platform provisioning:** VM provisioning, Omarchy installation, accounts and guest administrative rights, private access, external isolation, and platform restart behavior.
- **Dotfiles:** the user environment on that workstation, chezmoi, bootstrap credentials, Git/SSH configuration, and their operational documentation.
- **Future harness or workspace setup:** model/provider choice, authentication, agent services, integrations, workspace location, identity, memory, and task behavior.

Keep the default Omarchy environment where it already provides the needed capability. Extend its configuration without replacing unrelated shell setup or tool settings.

## Scope

Keep only what serves the Omarchy fundamentals or their maintenance and validation. Remove support for macOS, Homebrew, WSL, and other Linux distributions. Do not install a second shell or duplicate Omarchy's desktop and shell conveniences just to preserve the previous dotfiles layout.

The core bootstrap must not require OpenClaw, Codex, Claude, Node.js for those CLIs, Telegram credentials, a particular workspace repository, or a harness-specific directory. Harness selection and integration are deferred; no optional-harness framework is needed now.

Keep credentials out of Git and volatile runtime state outside chezmoi management. Use simple prerequisite checks and clear failures rather than silent skips or protocol fallbacks.

## Success criteria

- A human can prepare the intended Omarchy account with minimal manual work.
- Bash exposes the documented credential and chezmoi commands without exporting the service-account token into the parent shell.
- The account can authenticate to GitHub over SSH and produce a verifiable signed Git commit.
- Reapply preserves Omarchy configuration and produces no managed-file drift.
- The narrow, documented recovery paths work.
- The result requires no choice of agent harness.

The implementation sequence and outstanding evidence are in the ignored local `PLAN.md` (when present).
