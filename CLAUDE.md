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
- **desktop-channel/** — MCP channel server on desktop (port 8789)
- **coord.sh** — shell helpers (`send_to_phone`, `send_to_desktop`, etc.)
- **phone-bootstrap.sh** — SSH into phone, start fresh channel session
- **voice-agent/** — hands-free voice assistant (speech-to-text → Claude → TTS)

## Task Protocol

```json
{"task_id": "d-001", "type": "exec", "body": "check battery level"}
```
Types: `exec`, `query`, `result`. Status: `done`, `error`, `need_human`.

## Prerequisites

Termux + Termux:API + Termux:Widget (F-Droid), Tailscale on both devices, Claude Code subscription.

## Gotchas

- Phone shebangs use Termux path: `#!/data/data/com.termux/files/usr/bin/bash`
- Channels use experimental `--dangerously-load-development-channels` flag
- stdout reserved for MCP stdio — no `console.log`
- Voice agent uses `claude -p` with `--output-format json`
