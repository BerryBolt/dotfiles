# T3 Code MCP for Hermes

Hermes connects to T3 Code's MCP server as `t3-code`, so it can list, read, settle, and snooze threads. The `t3` CLI can only start, message, list one project's threads, and show a thread. The Hermes config template declares the server and exposes only the tools the open-work job needs.

## Approve the connection

T3 Code issues the token through OAuth. The agent approves it on this machine with a one-time pairing code, so no one has to open a browser.

1. Start the login and leave it waiting for the callback:

   ```bash
   BROWSER=/bin/true hermes mcp login t3-code --flow browser
   ```

   It prints an authorize URL for `http://127.0.0.1:3773/oauth/mcp/authorize`.
2. Issue a pairing code limited to the MCP scopes:

   ```bash
   t3 auth pairing create --scope orchestration:read --scope orchestration:operate --ttl 5m --label hermes-mcp-approval --json
   ```

3. POST to `http://127.0.0.1:3773/oauth/mcp/decision` with JSON. Set `authorization` to the authorize URL's query parameters (`response_type`, `client_id`, `redirect_uri`, `code_challenge`, `code_challenge_method`, `state`, `resource`). Set `decision` to `{"_tag": "pairing-code", "access": "auto", "code": <the pairing credential>}`.
4. Request the `redirectTo` URL from the response. It is Hermes' loopback callback, and the login prints `Authenticated`.

Keep the pairing credential and the token out of logs. The pairing code is single use.

## Renewal

The token lasts 30 days, and T3 Code offers no refresh grant. Hermes keeps it in `~/.hermes/mcp-tokens/t3-code.json`, which is runtime state, so a rebuilt machine approves again. The open-work pre-check wakes the agent three days before expiry and fails with an alert on a rejected token. Renew it with the steps above.

## The open-work job

Apply script 84 registers the `open-work` job every ten minutes. Its pre-check, `~/.hermes/scripts/open-work.py`, reads unsettled T3 threads over MCP and the agent's open pull requests through `gh`. It saves what it saw in `~/.hermes/state/open-work.json` and wakes the agent only for new, changed, stalled, or long-unresolved items. The agent then follows `~/brain/routines/open-work.md` and reports to Telegram.

Check it with `hermes cron list` and `hermes cron run open-work`.
