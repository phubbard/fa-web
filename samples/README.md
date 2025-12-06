# Sample Files

This directory contains sample audio and output files for testing the FluidAudio transcription service.

## Files

### Input
- **episode.mp3** - Sample podcast episode (48MB, ~70 minutes)
  - The Grenado podcast episode used for testing

### FluidAudio Outputs (from CLI)
- **results.json** - Diarization output from `fluidaudio process`
  - Contains speaker segments with timing and embeddings
  - Format: `{segments: [{speakerId, startTimeSeconds, endTimeSeconds, embedding, qualityScore}]}`

- **transcription.json** - Raw transcription from `fluidaudio transcribe`
  - Plain text output, no structure
  - Used to understand what FluidAudio transcribe returns

- **whisper-output.json** - Simple array format
  - Format: `[[timestamp, "SPEAKER_ID", "text"], ...]`
  - Not the final WhisperX format

### Reference Outputs
- **whisperx-reference-output.json** - Original WhisperX output (from Flask app)
  - Target format we're matching
  - Contains segments with speaker labels, timestamps, text, and word-level details
  - Format: `{segments: [{speaker, start, end, text, words: [{word, start, end, score, speaker}]}]}`

### Metadata
- **speaker-map.json** - Manual speaker ID to name mapping
  - Maps SPEAKER_00, SPEAKER_01, etc. to real names
  - Used in post-processing, not part of core workflow

## Testing

To test the service with the sample audio:

```bash
# Test the API
curl -X POST http://localhost:5051/submit/test-podcast/1 \
  -F file=@samples/episode.mp3 \
  -o output.json

# Compare with reference
diff <(jq -S . output.json) <(jq -S . samples/whisperx-reference-output.json)
```

## Output Format

The service produces WhisperX-compatible JSON:

```json
{
  "segments": [
    {
      "speaker": "S1",
      "start": 3.92,
      "end": 62.0,
      "text": " Hey, how's it going?...",
      "words": [
        {
          "word": "Hey",
          "start": 3.92,
          "end": 4.16,
          "score": 0.97,
          "speaker": "S1"
        }
      ]
    }
  ]
}
```
