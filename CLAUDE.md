# CLAUDE.md — termux

Run Claude Code on Android via Termux with two-way communication between phone and desktop over Tailscale.

## Network

| Device | Tailscale IP | Port | Role |
|--------|-------------|------|------|
| Phone (Pixel 7 Pro) | 100.74.17.91 | 8788 | phone-channel server |
| Desktop | 100.99.44.89 | 8789 | desktop-channel server |

## Components

- **setup.sh** — one-time Termux setup (Node.js, Python, Claude Code, termux-api)
- **transfer-auth.py** — QR code auth transfer from desktop to phone
- **phone-channel/** — MCP channel server on phone (port 8788)
  - **start.sh** — start channel in tmux with wake lock (idempotent)
  - **run-channel.sh** — auto-restart loop with exponential backoff, auto-accepts dev channel prompt
  - **health-restart.sh** — health check + restart if down (run locally or via SSH)
- **desktop-channel/** — MCP channel server on desktop (port 8789)
- **coord.sh** — shell helpers (`send_to_phone`, `send_to_desktop`, etc.)
- **phone-bootstrap.sh** — SSH into phone, check health, restart if needed
- **boot/start-channel.sh** — Termux:Boot auto-start script (copy to `~/.termux/boot/`)
- **voice-agent/** — hands-free voice assistant (speech-to-text → Claude → TTS)

## Task Protocol

```json
{"task_id": "d-001", "type": "exec", "body": "check battery level"}
```
Types: `exec`, `query`, `result`. Status: `done`, `error`, `need_human`.

## Prerequisites

Termux + Termux:API + Termux:Widget (F-Droid), Tailscale on both devices, Claude Code subscription.

## Reliability

The phone channel is designed to stay up unattended:

1. **tmux** — channel runs in a detached tmux session, survives terminal close
2. **Wake lock** — `termux-wake-lock` prevents Android from killing Termux
3. **Auto-restart** — `run-channel.sh` restarts claude on crash with exponential backoff (5s → 300s cap)
4. **Auto-accept** — dev channel confirmation prompt is auto-accepted via `tmux send-keys`
5. **Boot start** — `boot/start-channel.sh` in `~/.termux/boot/` starts channel on device boot

### Android settings (manual, one-time)

- **Tailscale**: Settings → Always-on VPN, enable for Tailscale
- **Battery optimization**: Settings → Battery → Unrestricted for Termux, Termux:API, Termux:Boot, Tailscale
- **Termux:Boot**: Install from F-Droid, grant autostart permission
- **allow-external-apps**: Already enabled in `~/.termux/termux.properties`

### Desktop commands

```bash
# Check health
curl -sf http://100.74.17.91:8788/health

# Restart from desktop
bash phone-bootstrap.sh

# SSH and check manually
ssh -p 8022 100.74.17.91 'tmux attach -t claude'
```

## Gotchas

- Phone shebangs use Termux path: `#!/data/data/com.termux/files/usr/bin/bash`
- Channels use experimental `--dangerously-load-development-channels` flag
- stdout reserved for MCP stdio — no `console.log`
- Voice agent uses `claude -p` with `--output-format json`
- Claude Code detects pipe on stdin and switches to print mode — never pipe into claude, let it run on a pty
