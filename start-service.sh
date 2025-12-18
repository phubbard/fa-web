#!/bin/bash
# Start fa-web transcription service

cd "$(dirname "$0")"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Kill any existing instance
log "Killing any existing instance on port 5051..."
lsof -ti:5051 | xargs kill -9 2>/dev/null || true
sleep 2

# Start the service (properly daemonized)
log "Starting fa-web service..." >> logs/stdout.log
nohup .build/release/App >> logs/stdout.log 2>> logs/stderr.log </dev/null &
disown

log "Service started on port 5051"
