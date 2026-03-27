#!/usr/bin/env python3
"""Display Claude Code credentials as a QR code for scanning on Android/Termux."""

import json
import base64
import os
import sys

CREDS_PATH = os.path.expanduser("~/.claude/.credentials.json")

def main():
    if not os.path.exists(CREDS_PATH):
        print(f"No credentials found at {CREDS_PATH}")
        print("Run 'claude auth login' on this machine first.")
        sys.exit(1)

    with open(CREDS_PATH, "r") as f:
        creds = f.read().strip()

    # Base64 encode to avoid QR issues with special characters
    encoded = base64.b64encode(creds.encode()).decode()

    # Check size — QR codes max out around 3KB
    if len(encoded) > 2953:
        print("Credentials file too large for a single QR code.")
        sys.exit(1)

    try:
        import qrcode
    except ImportError:
        print("Install qrcode: pip install qrcode")
        sys.exit(1)

    # Generate and print QR code to terminal
    qr = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_L)
    qr.add_data(encoded)
    qr.make(fit=True)

    print()
    print("=== Claude Code Auth Transfer ===")
    print("Scan this QR code with your phone, then in Termux run:")
    print()
    print('  mkdir -p ~/.claude && echo "<scanned text>" | base64 -d > ~/.claude/.credentials.json')
    print()
    qr.print_ascii(invert=True)
    print()
    print("QR contains base64-encoded credentials. Expires when you re-auth.")
    print("WARNING: Don't share this QR code — it contains your auth token.")

if __name__ == "__main__":
    main()
