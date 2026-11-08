# Link T3 Code

Use this procedure to let your owner work with this workstation's projects and agent threads from their T3 Code desktop app.

## Prerequisites

- Ask the platform owner to provide tailnet membership for this workstation and your owner's desktop. Tailnet membership belongs to the platform, not this repo.
- Use the T3 Code installation and `t3code.service` provided by apply script 70, `home/.chezmoiscripts/run_once_after_70-install-t3.sh`. Check the service with `t3 service status`.
- Apply this repo's settings template for `~/.t3/userdata/settings.json`. It sets `linkedEnvironmentsEnabled` to `true` and keeps T3's other settings.

## Expose T3 on the tailnet

Run these commands on the workstation once:

```bash
sudo tailscale set --operator="$USER"
tailscale serve --bg --https=3773 http://127.0.0.1:3773
tailscale serve status
```

Check that the status shows a tailnet-only HTTPS address on port 3773 that proxies to `http://127.0.0.1:3773`.

This step is manual and lives in Tailscale's state, not in this repo. Repeat it after rebuilding the machine.

## Link from the owner's desktop

1. In your owner's T3 Code desktop app, add a linked environment with the address `https://<machine>.<tailnet>.ts.net:3773`. Replace the placeholders with this workstation's Tailscale DNS name and select full access.
2. On the workstation, run plain `t3 pair`:

   ```bash
   t3 pair
   ```

3. Enter only the pairing token in the link card on your owner's desktop before the token expires. Never put the token in chat. If it expires, run `t3 pair` again and use the new token.
4. Check that the link shows reachable in your owner's T3 Code app.

Your owner's SSH access for this machine belongs in their personal dotfiles. Use password-only authentication and disable agent forwarding for that access.

## Troubleshooting

### Nothing answers as a T3 Code environment

If the link card reports "Nothing at ... answered as a T3 Code environment", check `tailscale serve status`. Serve may not be running, or the link may use the wrong port. Run the manual serve commands above and use port 3773 in the link address.

### Linked environments is off

If the link card reports "Linked environments is off on that machine", the settings key may be missing. Apply the dotfiles revision that declares it, check the value, and restart the service:

```bash
chezmoi-with-op apply ~/.t3/userdata/settings.json
jq .linkedEnvironmentsEnabled ~/.t3/userdata/settings.json
systemctl --user restart t3code.service
```

Check that `jq` prints `true`, then retry the link.

### Tailscale pairing fails on port 443

If pairing reports `TailscaleServeFailedError ... port 443`, do not use `t3 pair --tailscale`. That option tries HTTPS port 443. Use the manual serve on port 3773 and plain `t3 pair` instead.
