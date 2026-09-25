# AGENTS.md

This repo is the local `chezmoi` source repo for the agent's complete Omarchy workstation setup.

## Purpose

This repo is the agent's setup: one command from a fresh Omarchy install to the complete, working account, and reapply to converge. It owns packages and tools, OS maintenance, all user-level configuration, credential bootstrap from 1Password, Git/SSH/GitHub access, runtime services, integrations, and safe resumption, plus the policies and runbooks for them.

The workspace repo owns the agent's persona, instructions, projects, and working material. Mutable runtime state stays out of both.

## Read this first

Before making changes here, read:

1. `VISION.md` for the governing direction of this repo.
2. `ARCHITECTURE.md` for the timeless system reference (how bootstrap works, layer model, invariants).
3. `README.md` for the repo overview and install flow.
4. Local `PLAN.md`, when present, for the implementation plan and private execution context. It is intentionally ignored and absent from public clones.
5. `policies/README.md` for the policy map.
6. The specific policy or runbook that matches the task.

Any work done in this repo MUST align with `VISION.md` and MUST NOT violate the invariants in `ARCHITECTURE.md` unless there is a documented reason not to.

## Current scope and handoff

- Omarchy is the only installation target. Build on its defaults and supported commands; do not break its initialization or its updates.
- Deliver the full setup incrementally. Add each capability (tools, packages, desktop/terminal/theme settings, agent CLIs, services, integrations) as its own validated increment. Track the sequence in `PLAN.md`.
- Describe only implemented and verified behavior as current. Record pending work and validation evidence in `PLAN.md`, not as claims in public docs.
- `PLAN.md` is the single local implementation checklist and private handoff. It is ignored by Git; never stage or force-add it.
- Deliver coherent atomic commits directly on `main`; do not create implementation branches. `https://berrybolt.bot/install.sh` redirects to `install.sh` on `main`, so every push publishes the installer. Push only locally checked commits. VM testing installs the pushed commit from the public GitHub repository, and the installer and chezmoi source must use the same full commit SHA. Follow PLAN for the loop; do not substitute an uncommitted copy of the working tree.
- The first milestone is a passing fresh install. Read the ignored local `PLAN.md` for the designated VM, credential source, and session-specific execution authority. Reset the authorized local test setup between attempts while preserving the Omarchy/access baseline; broader checks follow the first passing install.
- This repository is public. Do not commit credentials, VM access details, private infrastructure names/topology, or private repository links, including for disposable environments. Use generic public examples and keep operational context in ignored local files.

## Repo model

- This repo is managed through `chezmoi`.
- `home/` contains files rendered into the target filesystem.
- `policies/`, `runbooks/`, and `skills/` stay in the local `chezmoi` source repo as source-of-truth docs.
- Prefer defaults unless there is a documented reason not to.

## Boundaries

- `dotfiles` owns the agent's workstation setup:
  - packages, tools, and OS maintenance
  - all user-level configuration, managed through `chezmoi`
  - credential bootstrap from 1Password; Git, SSH, and GitHub access
  - runtime services, integrations, and safe resumption after a restore
  - operational policies, and setup and recovery runbooks
- the agent workspace repo owns:
  - persona and instructions
  - projects and working material
- the platform owns the VM, the Omarchy installation and initial access, network isolation, backups, and host recovery; it hands a verified VM to this repo.
- mutable runtime state (sessions, caches, databases, working data) stays on the machine, outside Git, and a rebuild does not need it.

## Vision

Use `VISION.md` as the governing document for architecture and direction in this repo.

An ignored local `PLAN.md` may track implementation of that vision; public documentation must stand on its own.

## Working rules

- Use `policies/chezmoi.md` for managed-file rules and the chezmoi workflow.
- Use `policies/credentials.md` for 1Password and secret handling.
- Use `policies/dependencies.md` for what Omarchy supplies and what this repo adds.
- Use `policies/git.md` for repo workflow.
- Prefer simple, load-bearing bootstrap paths over defensive fallbacks. When a dependency or invariant is required for correct operation, do not add best-effort continuations, silent skips, placeholder recovery, or alternate protocol fallbacks just to keep going; fail fast with a clear error instead. If a flow is intentionally recoverable or best-effort, that exception must be documented explicitly in the architecture or runbook that owns it.
- Do not create unit tests, fixture suites, or mocks. Validate on the disposable Omarchy VM with `tests/assertions.sh` and `tests/recovery.sh` against the pushed SHA.
- Keep secrets out of git.
- Keep volatile runtime state out of git.
- Keep docs here generic to bootstrap and operations. If a doc is mainly about one agent's runtime behavior, it probably belongs in that agent's workspace repo.
