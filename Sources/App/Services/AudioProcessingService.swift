import Foundation
import Vapor
import Fluent
import FluidAudio

/// Service that processes audio files using FluidAudio and generates WhisperX-compatible output
actor AudioProcessingService {
    private let asrManager: AsrManager
    private let diarizerManager: OfflineDiarizerManager
    private let aligner: TranscriptionAligner
    private let formatter: WhisperXFormatter

    init() {
        self.asrManager = AsrManager()
        self.diarizerManager = OfflineDiarizerManager()
        self.aligner = TranscriptionAligner()
        self.formatter = WhisperXFormatter()
    }

    /// Process an audio file and generate WhisperX-compatible transcription
    /// - Parameters:
    ///   - audioPath: Path to the audio file
    ///   - jobID: UUID of the job
    ///   - podcast: Podcast name
    ///   - episodeNumber: Episode number
    ///   - db: Database connection for logging
    /// - Returns: Path to the output JSON file
    func processAudio(
        audioPath: String,
        jobID: UUID,
        podcast: String,
        episodeNumber: String,
        on db: Database
    ) async throws -> String {

        // Helper function to log to database
        func log(_ message: String) async {
            do {
                let logEntry = JobLog(jobID: jobID, message: message)
                try await logEntry.create(on: db)
                print("[Job \(jobID)] \(message)")
            } catch {
                print("[Job \(jobID)] Failed to log: \(error)")
            }
        }

        await log("Starting audio processing for \(podcast) episode \(episodeNumber)")

        // 1. Load and convert audio
        await log("Loading audio file: \(audioPath)")
        let audioSamples: [Float]
        do {
            let converter = AudioConverter()
            audioSamples = try converter.resampleAudioFile(path: audioPath)
            await log("Audio loaded: \(audioSamples.count) samples (\(audioSamples.count / 16000) seconds)")
        } catch {
            await log("ERROR: Failed to load audio: \(error)")
            throw error
        }

        // 2. Initialize models (first time only - they're cached)
        await log("Initializing ASR models")
        do {
            let asrModels = try await AsrModels.downloadAndLoad(version: .v3)
            try await asrManager.initialize(models: asrModels)
            await log("ASR models initialized")
        } catch {
            await log("ERROR: Failed to initialize ASR: \(error)")
            throw error
        }

        await log("Initializing diarization models")
        do {
            try await diarizerManager.prepareModels()
            await log("Diarization models initialized")
        } catch {
            await log("ERROR: Failed to initialize diarization: \(error)")
            throw error
        }

        // 3. Run ASR (transcription)
        await log("Running speech-to-text transcription")
        let asrResult: ASRResult
        do {
            asrResult = try await asrManager.transcribe(audioSamples, source: .system)
            await log("Transcription complete: \(asrResult.text.count) characters")
            await log("Confidence: \(asrResult.confidence)")
        } catch {
            await log("ERROR: Transcription failed: \(error)")
            throw error
        }

        // 4. Run diarization (speaker identification)
        await log("Running speaker diarization")
        let diarizationResult: DiarizationResult
        do {
            diarizationResult = try await diarizerManager.process(audio: audioSamples)
            await log("Diarization complete: \(diarizationResult.segments.count) speaker segments found")

            let speakerSet = Set(diarizationResult.segments.map { $0.speakerId })
            await log("Unique speakers: \(speakerSet.joined(separator: ", "))")
        } catch {
            await log("ERROR: Diarization failed: \(error)")
            throw error
        }

        // 5. Align words to speakers
        await log("Aligning words with speakers")
        let alignedSegments = aligner.align(asrResult: asrResult, diarizationResult: diarizationResult)
        await log("Alignment complete: \(alignedSegments.count) segments")

        // 6. Build WhisperX format and save
        await log("Building WhisperX format output")
        let outputPath = "/tmp/\(podcast)_\(episodeNumber)_transcription.json"
        do {
            try formatter.save(segments: alignedSegments, to: outputPath)
            await log("Output saved to: \(outputPath)")
        } catch {
            await log("ERROR: Failed to save output: \(error)")
            throw error
        }

        await log("Processing complete!")
        return outputPath
    }
}
