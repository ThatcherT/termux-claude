# Phone Channel Setup

## On the phone (Termux) — one time

```bash
# get the files onto the phone (pick one)
git clone <repo> ~/phone-channel
# or scp from desktop:
# scp -P 8022 -r phone-channel/ phone-ip:~/phone-channel/

cd ~/phone-channel
pkg install nodejs  # if not already installed
npm install

# test it works
node channel.mjs
# ctrl-c
```

## Start Claude Code with the channel

```bash
cd ~/phone-channel
claude --dangerously-load-development-channels server:phone-channel
```

Use tmux/screen so it stays alive:
```bash
pkg install tmux
tmux new -s claude
cd ~/phone-channel
claude --dangerously-load-development-channels server:phone-channel
# ctrl-b d to detach
```

## From the desktop

Send a message:
```bash
curl -d "say hello using termux-tts-speak" http://100.74.17.91:8788
```

Watch replies:
```bash
curl -N http://100.74.17.91:8788/events
```

Health check:
```bash
curl http://100.74.17.91:8788/health
```
