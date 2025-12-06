#!/bin/bash
# Uninstall fa-web launchd service

set -e

echo "Stopping and unloading service..."
launchctl stop com.phfactor.fa-web 2>/dev/null || true
launchctl unload ~/Library/LaunchAgents/com.phfactor.fa-web.plist 2>/dev/null || true

echo "Removing plist file..."
rm -f ~/Library/LaunchAgents/com.phfactor.fa-web.plist

echo ""
echo "✅ fa-web service uninstalled!"
