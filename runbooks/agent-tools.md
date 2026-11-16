# Shared agent skills

The optional `data.agent_tools_repository` value names the GitHub source of shared agent skills
as `owner/repository`. Leave it empty on a workstation that does not need those skills.
Set it through `chezmoi edit-config`; the configuration template preserves it on reinitialization.

The account must be able to clone that repository through its existing GitHub SSH sign-in.
Private repositories owned by personal GitHub accounts require collaborator write access.
The setup uses that access only for source reads. It creates no credential and copies no login.

The git-repo external clones the source into `~/code/<owner>/<repository>`. Its zero refresh
period leaves source updates explicit. Use chezmoi's refresh option after reviewing a source
update; Git accepts only a fast-forward. Do not overwrite local edits or unpublished commits.
Chezmoi delegates the checkout to Git, so its contents do not appear in `chezmoi diff`.
Review the external declaration and verify the checkout's origin and commit separately.

Managed symlinks expose only `skills/manage-handbook-hosts` to Codex and Claude Code. This is
the source repository's documented symlink installation, owned here so reapply restores it.
The skill's T3 instructions stay beside it and remain readable through either link.

Review `chezmoi-with-op diff` for the two skill paths. Apply the source checkout and the two
skill paths with `chezmoi-with-op apply`. Verify the resolved links, `SKILL.md`, and
`references/t3-execution.md`. Reapply must leave those links unchanged.

This integration installs instructions only. It starts no agent, host update, or scheduler.
A manual T3 request can invoke the skill after the owner authorizes that update. An autonomous
host service requires a separate reviewed implementation and activation decision.
