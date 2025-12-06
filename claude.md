# Overview

The project here is to replace an existing system. The current system, in the ../flask-whisperx directory, is a Flask wrapper and app
on top of the WhisperX speech-to-text model. I use it as part of an open-source system to transcribe podcasts. It has two aspects:

1. REST API - this is the most important. Invoked using wget, the mp3 file is uploaded and episode # and podcast as URL parameters. On the remote side, the Makefile excerpt is
episode-transcribed.json:
        @echo Now transcribing episode $(ep_num) of $(podcast)
        curl -s -X POST http://axiom.phfactor.net:5050/submit/$(podcast)/$(ep_num) -F file=@episode.mp3 -o episode-transcribed.json --fail --remove-on-error

This uses WhisperX to do both STT and diarization. See the episode-transcribed.json sample in the directory here for its structure. Goal #1 is to replicate this output format _exactly_.

2. Web interface - simple command and control interface - we can come back to this.

# Tech stack

Importantly, we are leaving python and switching to Swift. The new STT engine is FluidAudio, which invoked by CLI:

We have a working instance checked out in the ../FluidAudio directory.

swift run fluidaudio process episode.mp3 --output results.json --threshold 0.6 --mode offline

produces a json file results.json as seen the current directory. Two goals here:

1. We want a REST API, say port 5051, using only Swift.
2. Web interface will be tackled after the REST API. We need to either invoke the CLI or (my preference) use the Swift APIs from the webapp.

API docs are at https://github.com/FluidInference/FluidAudio/blob/main/Documentation/SpeakerDiarization.md

