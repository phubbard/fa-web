#!/bin/bash
# Install fa-web as a launchd service

set -e

echo "Building fa-web in release mode..."
swift build -c release

echo "Creating logs directory..."
mkdir -p logs

echo "Installing launchd service..."
cp com.phfactor.fa-web.plist ~/Library/LaunchAgents/

echo "Loading service..."
launchctl unload ~/Library/LaunchAgents/com.phfactor.fa-web.plist 2>/dev/null || true
launchctl load ~/Library/LaunchAgents/com.phfactor.fa-web.plist

echo ""
echo "✅ fa-web service installed!"
echo ""
echo "Service will start automatically at boot."
echo ""
echo "Management commands:"
echo "  Start:   launchctl start com.phfactor.fa-web"
echo "  Stop:    launchctl stop com.phfactor.fa-web"
echo "  Restart: launchctl kickstart -k gui/\$(id -u)/com.phfactor.fa-web"
echo "  Status:  launchctl list | grep fa-web"
echo "  Logs:    tail -f logs/stdout.log logs/stderr.log"
echo ""
echo "Service is now running at: http://localhost:5051"
