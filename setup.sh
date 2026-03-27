#!/data/data/com.termux/files/usr/bin/bash
# Claude Code on Android — Termux Setup Script
# Run this after installing Termux from F-Droid
# Usage: bash setup.sh

set -e

echo "=== Claude Code Android Setup ==="
echo ""

# Step 1: Update Termux packages
echo "[1/6] Updating Termux packages..."
yes | pkg update && pkg upgrade -y

# Step 2: Install core dependencies
echo "[2/6] Installing core dependencies..."
pkg install -y nodejs-lts python git openssh build-essential binutils

# Step 3: Set up tmp directory workaround
# Claude Code hardcodes /tmp/claude which Android restricts
echo "[3/6] Configuring tmp directory workaround..."
mkdir -p "$HOME/.tmp"

SHELL_RC="$HOME/.bashrc"
if [ -f "$HOME/.zshrc" ] && command -v zsh &> /dev/null; then
    SHELL_RC="$HOME/.zshrc"
fi

if ! grep -q "CLAUDE_CODE_TMPDIR" "$SHELL_RC" 2>/dev/null; then
    echo '' >> "$SHELL_RC"
    echo '# Claude Code tmp directory workaround for Termux' >> "$SHELL_RC"
    echo 'export CLAUDE_CODE_TMPDIR="$HOME/.tmp"' >> "$SHELL_RC"
fi
export CLAUDE_CODE_TMPDIR="$HOME/.tmp"

# Step 4: Install Claude Code
echo "[4/6] Installing Claude Code..."
npm install -g @anthropic-ai/claude-code

# Step 5: Install common CLI tools
echo "[5/6] Installing common CLI tools..."
pip install awscli

# Step 6: Install Termux:API tools (if the companion app is installed)
echo "[6/6] Installing Termux:API tools..."
pkg install -y termux-api 2>/dev/null || echo "Note: Install the Termux:API app from F-Droid for Android API access"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Restart Termux (or run: source $SHELL_RC)"
echo "  2. Run: claude"
echo "  3. Authenticate with your Anthropic account"
echo ""
echo "Installed:"
echo "  - Node.js $(node --version)"
echo "  - npm $(npm --version)"
echo "  - Claude Code $(claude --version 2>/dev/null || echo 'installed')"
echo "  - Git $(git --version | cut -d' ' -f3)"
echo "  - Python $(python --version | cut -d' ' -f2)"
echo "  - AWS CLI $(aws --version 2>/dev/null | cut -d' ' -f1 || echo 'installed')"
echo ""
echo "Tips:"
echo "  - Use a bluetooth keyboard for a better experience"
echo "  - Run 'termux-setup-storage' to access phone storage at ~/storage/"
echo "  - Install Termux:API app from F-Droid for SMS, camera, GPS, etc."
