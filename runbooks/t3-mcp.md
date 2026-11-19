# T3 Code MCP for Hermes

Hermes connects to T3 Code's MCP server as `t3-code`, so it can list, read, settle, and snooze threads. The `t3` CLI can only start, message, list one project's threads, and show a thread. The Hermes config template declares the server and exposes only the tools the open-work job needs.

## Approve the connection

T3 Code issues the token through OAuth. The agent approves it on this machine with a one-time pairing code, so no one has to open a browser.

1. Start the login and leave it waiting for the callback:

   ```bash
   BROWSER=/bin/true hermes mcp login t3-code --flow browser
   ```

   It prints an authorize URL for `http://127.0.0.1:3773/oauth/mcp/authorize`.
2. Issue a pairing code with the scopes of T3 Code's `full-access` client level:

   ```bash
   t3 auth pairing create --scope orchestration:read --scope orchestration:operate --scope settings:write --scope source-control:write --ttl 5m --label hermes-mcp-approval --json
   ```

3. POST to `http://127.0.0.1:3773/oauth/mcp/decision` with JSON. Set `authorization` to the authorize URL's query parameters (`response_type`, `client_id`, `redirect_uri`, `code_challenge`, `code_challenge_method`, `state`, `resource`). Set `decision` to `{"_tag": "pairing-code", "access": "full-access", "code": <the pairing credential>}`. The agent's threads run in full-access mode, and T3 Code refuses to settle them from a client with a lower level.
4. Request the `redirectTo` URL from the response. It is Hermes' loopback callback, and the login prints `Authenticated`.

Keep the pairing credential and the token out of logs. The pairing code is single use. After a new approval, revoke the previous `Hermes Agent` client session listed by `t3 auth session list`.

A running gateway picks up the new token. If the server was parked before its first token, the gateway can reconnect without registering the tools, so check that `gateway.log` shows `registered 4 tool(s)` for `t3-code`, and restart the gateway if it doesn't.

## Renewal

The token lasts 30 days, and T3 Code offers no refresh grant. Hermes keeps it in `~/.hermes/mcp-tokens/t3-code.json`, which is runtime state, so a rebuilt machine approves again. The open-work pre-check wakes the agent three days before expiry and fails with an alert on a rejected token. Renew it with the steps above.

## The open-work job

Apply script 84 registers the `open-work` job every ten minutes, once the workspace checkout exists. Its pre-check, `~/.hermes/scripts/open-work.py`, reads unsettled T3 threads over MCP and queries GitHub through `gh`. It checks open issues assigned to the agent, open pull requests authored by or assigned to the agent, and direct requests for its review. It fingerprints each pull request's head, checks, review state, and other people's comments, inline comments, and reviews, including edits. For assigned issues it tracks the assignment, title, body, and other people's comments. For requested reviews it tracks the request and the commit. The workspace's `policies/github-pickup.json` lists the GitHub logins allowed to make these requests under `*` or an exact `owner/repo`. It saves what it saw in `~/.hermes/state/open-work.json` and wakes the agent only for new, changed, stalled, or long-unresolved items. The agent then follows `~/brain/routines/open-work.md` and reports to Telegram. Each run sees the job's previous report.

The pre-check is recoverable by design:

- T3 Code and GitHub are separate sources. When one fails, the other still runs, and the failing source's items keep their last state. A source that fails three runs in a row becomes a maintenance item. A missing token counts as a failing T3 source.
- When the agent run fails or the scheduler records no completion after a wake, the next three runs wake it again for the same items.
- A GitHub search that reaches its 1,000-result limit fails the source rather than miss work.
- Apply script 60 retries a refused gateway restart every minute until it succeeds. After two hours it writes `~/.hermes/state/gateway-restart-pending`, which becomes a maintenance item. Find the session that stays live, let it finish or stop it deliberately, and restart the gateway.

Use `hermes cron list` to check registration. To verify automatic pickup, use a repository shared with the test account. Have an authorized requester assign an issue and request a review. Observe the scheduled job, the T3 threads, and the resulting GitHub work. Check the next scheduled run for duplicate work. Request another review of the same commit and verify that the new request starts one review.

To route reports to a topic in the owner's chat, set the optional `open-work topic ID` text field on the selected Telegram bot item in 1Password to a positive integer. Apply renders it as `OPEN_WORK_TELEGRAM_TOPIC_ID` in the private `~/.hermes/.env`. Script 84 combines it with `TELEGRAM_HOME_CHANNEL` to register `telegram:<owner-chat>:<topic>`. Reapply repairs delivery drift and preserves a paused job. A rebuilt account restores the route from 1Password without needing the old cron database. Keep chat and topic IDs out of public source.

If the field is absent or empty, apply clears the local topic selection and registers `telegram`, which uses Hermes' default destination. An invalid topic value stops apply.
