# FluidAudio Web Transcription Service

A Swift-based web service for podcast transcription with speaker diarization, replacing the Flask/WhisperX implementation with FluidAudio.

## Overview

This service provides:
- **REST API** for audio transcription (compatible with WhisperX output format)
- **Speaker diarization** (who spoke when)
- **Web UI** for job monitoring and management
- **Background processing** with real-time logging
- **SQLite database** for job tracking

## Tech Stack

- **Swift** with Vapor 4 web framework
- **FluidAudio** for ASR (speech-to-text) and diarization
- **Fluent ORM** with SQLite
- **Leaf** templating engine
- **Water.css** for UI styling

## Architecture

```
┌─────────────────────────────────────────────┐
│ User uploads MP3 via REST API               │
│ POST /submit/:podcast/:episode              │
└──────────────────┬──────────────────────────┘
                   │
                   ↓
┌─────────────────────────────────────────────┐
│ Background Processing Pipeline              │
│ 1. Load audio (16kHz mono conversion)      │
│ 2. Run ASR (word-level timestamps)         │
│ 3. Run diarization (speaker segments)      │
│ 4. Align words to speakers                 │
│ 5. Generate WhisperX JSON format           │
└─────────────────────────────────────────────┘
                   │
                   ↓
┌─────────────────────────────────────────────┐
│ Output: WhisperX-compatible JSON            │
│ /tmp/{podcast}_{episode}_transcription.json │
└─────────────────────────────────────────────┘
```

## Requirements

- macOS 13+ (for FluidAudio)
- Swift 5.9+
- Xcode Command Line Tools
- FluidAudio checked out in `../FluidAudio`

## Installation

### 1. Clone and Build

```bash
cd /Users/pfh/code/fa-web

# Build the project
swift build -c release
```

### 2. Install as Service (Auto-start at Boot)

```bash
./install-service.sh
```

This will:
- Build the release binary
- Install launchd service
- Start the service immediately
- Configure auto-start at boot

## API Reference

### Base URL
```
http://axiom.phfactor.net:5051
```

### Endpoints

#### **POST /submit/:podcast/:episode**
Submit an audio file for transcription.

**Example:**
```bash
curl -X POST http://axiom.phfactor.net:5051/submit/my-podcast/123 \
  -F file=@episode.mp3 \
  -o episode-transcribed.json \
  --fail --remove-on-error
```

**Parameters:**
- `:podcast` - Podcast name (URL path parameter)
- `:episode` - Episode number (URL path parameter)
- `file` - MP3 audio file (multipart form data)

**Response:**
WhisperX-compatible JSON:
```json
{
  "segments": [
    {
      "speaker": "S1",
      "start": 4.193548,
      "end": 20.764008,
      "text": " Hey, how's it going?",
      "words": [
        {
          "word": "Hey,",
          "start": 4.19,
          "end": 4.52,
          "score": 0.95,
          "speaker": "S1"
        }
      ]
    }
  ]
}
```

#### **GET /**
Web UI showing all jobs.

#### **GET /job/:jobId**
View job details and processing logs.

#### **POST /cleanup**
Remove all stuck "RUNNING" jobs.

## Web UI

Access at: `http://axiom.phfactor.net:5051`

Features:
- Job list with status, duration, and timestamps
- Real-time job monitoring (auto-refresh when running)
- Processing logs for debugging
- Clean, minimal Water.css styling

## Service Management

### Start/Stop/Restart

```bash
# Start
launchctl start com.phfactor.fa-web

# Stop
launchctl stop com.phfactor.fa-web

# Restart
launchctl kickstart -k gui/$(id -u)/com.phfactor.fa-web

# Check status
launchctl list | grep fa-web
```

### View Logs

```bash
# Real-time logs
tail -f logs/stdout.log logs/stderr.log

# View database
sqlite3 fa-web.db "SELECT * FROM jobs ORDER BY timestamp DESC LIMIT 10;"
```

### Uninstall Service

```bash
./uninstall-service.sh
```

## Development

### Run in Development Mode

```bash
# Build and run
swift run App

# Or with environment variable
LOG_LEVEL=trace swift run App
```

### Project Structure

```
fa-web/
├── Package.swift                 # Swift package dependencies
├── Sources/App/
│   ├── main.swift               # Entry point
│   ├── configure.swift          # App configuration
│   ├── routes.swift             # Route definitions
│   ├── Models/
│   │   ├── Job.swift            # Job model
│   │   └── JobLog.swift         # Log model
│   ├── Migrations/
│   │   ├── CreateJob.swift      # Job table migration
│   │   └── CreateLog.swift      # Log table migration
│   ├── Controllers/
│   │   └── WebController.swift  # Web & API handlers
│   └── Services/
│       ├── AudioProcessingService.swift   # Main processing pipeline
│       ├── TranscriptionAligner.swift     # Word-to-speaker alignment
│       └── WhisperXFormatter.swift        # JSON output formatting
├── Resources/Views/
│   ├── index.leaf               # Job list page
│   └── job.leaf                 # Job detail page
└── Tests/
```

### Database Schema

**jobs table:**
```sql
CREATE TABLE jobs (
  id UUID PRIMARY KEY,
  timestamp DATETIME,
  podcast TEXT NOT NULL,
  episode_number TEXT NOT NULL,
  job_id TEXT NOT NULL,
  elapsed INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL,
  return_code INTEGER
);
```

**logs table:**
```sql
CREATE TABLE logs (
  id UUID PRIMARY KEY,
  job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
  timestamp DATETIME,
  message TEXT NOT NULL
);
```

## How It Works

### 1. Audio Processing Pipeline

The `AudioProcessingService` orchestrates the entire workflow:

```swift
// 1. Load and convert audio to 16kHz mono Float32
let audioSamples = try AudioConverter.resampleAudioFile(path: audioPath)

// 2. Run ASR (Automatic Speech Recognition)
let asrResult = try await asrManager.transcribe(audioSamples)
// Returns: full text + word-level timestamps + confidence scores

// 3. Run speaker diarization
let diarizationResult = try await diarizerManager.process(audio: audioSamples)
// Returns: speaker segments with start/end times

// 4. Align words to speakers
let alignedSegments = aligner.align(asrResult, diarizationResult)
// Matches each word to its speaker based on timestamp overlap

// 5. Build WhisperX format
let json = formatter.buildWhisperXFormat(from: alignedSegments)
```

### 2. Word-to-Speaker Alignment Algorithm

The `TranscriptionAligner` matches ASR words to diarization speakers:

1. **For each word from ASR:**
   - Calculate word midpoint: `(start + end) / 2`
   - Find which speaker segment contains that midpoint

2. **Group consecutive words by speaker:**
   - When speaker changes, create new segment
   - Combine words into text
   - Preserve word-level timestamps

3. **Output aligned segments:**
   - Each segment has: speaker, start, end, text, words array

### 3. WhisperX Format Compatibility

Output exactly matches WhisperX structure:
- Segment-level: speaker, timestamps, combined text
- Word-level: individual words with timestamps and confidence
- Same field names and structure as original Flask/WhisperX app

## Performance

- **Real-time Factor**: ~120x on M4 Pro (processes 1 hour in ~30 seconds)
- **Models**: Auto-downloaded and cached on first run
- **Memory**: Efficient streaming for large audio files
- **Concurrent Jobs**: Processes one job at a time (configurable)

## Troubleshooting

### Models not downloading
```bash
# Set HuggingFace token if needed
export HF_TOKEN=your_token_here
swift run App
```

### Port already in use
```bash
# Check what's using port 5051
lsof -i :5051

# Kill process
kill -9 <PID>
```

### Database locked
```bash
# Stop service first
launchctl stop com.phfactor.fa-web

# Then access database
sqlite3 fa-web.db
```

### Build errors
```bash
# Clean build
swift package clean
rm -rf .build

# Rebuild
swift build
```

## Comparison with Flask/WhisperX

| Feature | Flask/WhisperX | FluidAudio/Vapor |
|---------|----------------|------------------|
| Language | Python | Swift |
| STT Engine | WhisperX | FluidAudio (Parakeet TDT) |
| Diarization | WhisperX | FluidAudio (WeSpeaker + VBx) |
| Performance | ~1x real-time | ~120x real-time |
| Platform | CUDA (GPU) | Apple Neural Engine |
| Output Format | ✅ Identical | ✅ Identical |
| REST API | ✅ Port 5050 | ✅ Port 5051 |
| Web UI | ✅ Flask/Jinja2 | ✅ Vapor/Leaf |

## License

See FluidAudio license: https://github.com/FluidInference/FluidAudio

## Credits

- **FluidAudio**: https://github.com/FluidInference/FluidAudio
- **Vapor**: https://vapor.codes
- **Water.css**: https://watercss.kognise.dev
