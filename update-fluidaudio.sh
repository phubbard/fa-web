#!/bin/bash
# Update FluidAudio to latest version and rebuild fa-web

set -e  # Exit on error

cd "$(dirname "$0")"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting FluidAudio update process..."

# Check if FluidAudio directory exists
if [ ! -d "../FluidAudio" ]; then
    log "ERROR: FluidAudio directory not found at ../FluidAudio"
    exit 1
fi

# Update FluidAudio
log "Updating FluidAudio from GitHub..."
cd ../FluidAudio
git fetch origin
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
log "Current branch: $CURRENT_BRANCH"
git pull origin $CURRENT_BRANCH
LATEST_COMMIT=$(git rev-parse --short HEAD)
log "Updated to commit: $LATEST_COMMIT"

# Return to fa-web directory
cd ../fa-web

# Clean Swift build cache
log "Cleaning Swift build cache..."
swift package clean

# Update package dependencies
log "Resolving package dependencies..."
swift package resolve

# Build release version
log "Building release version..."
swift build -c release

# Restart the service
log "Restarting fa-web service..."
lsof -ti:5051 | xargs kill -9 2>/dev/null || true
sleep 2

# Start service via launchd or directly
if launchctl list | grep -q "com.phfactor.fa-web"; then
    log "Reloading launchd service..."
    launchctl unload ~/Library/LaunchAgents/com.phfactor.fa-web.plist 2>/dev/null || true
    sleep 1
    launchctl load ~/Library/LaunchAgents/com.phfactor.fa-web.plist
else
    log "Starting service manually..."
    nohup .build/release/App >> logs/stdout.log 2>> logs/stderr.log </dev/null &
    disown
fi

sleep 3

# Verify service is running
if lsof -i:5051 > /dev/null 2>&1; then
    log "✓ Update complete! Service is running on port 5051"
else
    log "✗ WARNING: Service may not have started correctly"
    log "Check logs/stderr.log for errors"
    exit 1
fi
