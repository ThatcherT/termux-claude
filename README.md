# termux-claude

Claude Code running on an Android phone via Termux. two-way communication between phone and desktop over Tailscale.

## what's in here

**setup and auth**
- `setup.sh` installs Node, Python, Claude Code, termux-api, and patches the `/tmp` issue
- `transfer-auth.py` turns your desktop Claude credentials into a QR code you scan on the phone. no manual typing

**phone / desktop channels**
- `phone-channel/` is an MCP server on the phone. takes tasks from the desktop, runs them through Claude Code, sends replies back. HTTP on port 8788, SSE for watching replies
- `desktop-channel/` is the same thing but on the desktop, port 8789. phone can send tasks to the desktop the same way
- `coord.sh` has shell helpers for both sides: `send_to_phone`, `send_to_desktop`, health checks, SSH/SCP wrappers
- `phone-bootstrap.sh` SSHs into the phone and starts the phone-channel in a tmux session if it isn't already running

**voice agent**
- `voice-agent/` is a hands-free voice assistant on the phone. `termux-speech-to-text` for input, `termux-tts-speak` for output, Claude Code in between. activated from a Termux:Widget tap. multi-turn conversations with session persistence and daily log rotation

## prerequisites

- Android phone with [Termux](https://f-droid.org/packages/com.termux/) + [Termux:API](https://f-droid.org/packages/com.termux.api/) from F-Droid
- [Tailscale](https://tailscale.com/) on both phone and desktop
- Claude Code subscription

## quick start

on the phone in Termux:
```bash
bash setup.sh
```

transfer auth from desktop instead of logging in manually:
```bash
# on desktop
python transfer-auth.py
# scan the QR, paste the decoded string into ~/.claude/.credentials.json on the phone
```

start the phone channel:
```bash
cd ~/phone-channel && npm install
claude --dangerously-load-development-channels server:phone-channel
```

from the desktop, send a message:
```bash
curl -d "what's the battery level?" http://<phone-tailscale-ip>:8788
```

## architecture

both channels use the same pattern: an MCP server bridging Claude Code's experimental channel capability to an HTTP interface.

```
Desktop Claude <-stdio-> desktop-channel <-HTTP/SSE-> phone-channel <-stdio-> Phone Claude
```

either side can initiate tasks. task protocol is JSON with `task_id`, `type` (exec/query/result), and `body`. replies include a status: `done`, `error`, or `need_human`.

## network

everything runs over Tailscale. no port forwarding, no public endpoints.

| device | ip | port | role |
|--------|-----|------|------|
| phone | 100.74.17.91 | 8788 | phone-channel |
| desktop | 100.99.44.89 | 8789 | desktop-channel |
| phone ssh | 100.74.17.91 | 8022 | termux sshd |
