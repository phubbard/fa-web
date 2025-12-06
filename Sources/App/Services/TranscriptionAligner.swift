import Foundation
import FluidAudio

/// Aligns ASR word timings with diarization speaker segments
struct TranscriptionAligner {

    /// Aligns words from ASR with speakers from diarization
    /// - Parameters:
    ///   - asrResult: ASR result with word-level timings
    ///   - diarizationResult: Diarization result with speaker segments
    /// - Returns: Array of aligned segments with speaker labels and text
    func align(
        asrResult: ASRResult,
        diarizationResult: DiarizationResult
    ) -> [AlignedSegment] {
        guard let tokenTimings = asrResult.tokenTimings, !tokenTimings.isEmpty else {
            return []
        }

        let speakerSegments = diarizationResult.segments.sorted { $0.startTimeSeconds < $1.startTimeSeconds }

        // Group words by speaker segment
        var currentSegments: [AlignedSegment] = []
        var currentSpeaker: String? = nil
        var currentWords: [AlignedWord] = []
        var currentStart: TimeInterval? = nil
        var currentEnd: TimeInterval = 0

        for token in tokenTimings {
            // Find which speaker segment this word belongs to
            let speaker = findSpeaker(for: token, in: speakerSegments)

            // If speaker changed, save current segment and start new one
            if let prevSpeaker = currentSpeaker, speaker != prevSpeaker, !currentWords.isEmpty {
                let segment = AlignedSegment(
                    speaker: prevSpeaker,
                    start: currentStart ?? token.startTime,
                    end: currentEnd,
                    words: currentWords
                )
                currentSegments.append(segment)
                currentWords = []
                currentStart = nil
            }

            // Add word to current segment
            currentSpeaker = speaker
            if currentStart == nil {
                currentStart = token.startTime
            }
            currentEnd = token.endTime

            let word = AlignedWord(
                word: token.token,
                start: token.startTime,
                end: token.endTime,
                score: token.confidence,
                speaker: speaker
            )
            currentWords.append(word)
        }

        // Don't forget the last segment
        if !currentWords.isEmpty, let speaker = currentSpeaker, let start = currentStart {
            let segment = AlignedSegment(
                speaker: speaker,
                start: start,
                end: currentEnd,
                words: currentWords
            )
            currentSegments.append(segment)
        }

        return currentSegments
    }

    /// Finds which speaker segment a token belongs to based on temporal overlap
    private func findSpeaker(
        for token: TokenTiming,
        in speakerSegments: [TimedSpeakerSegment]
    ) -> String {
        let tokenMidpoint = Float((token.startTime + token.endTime) / 2)

        // Find speaker segment that contains the token midpoint
        for segment in speakerSegments {
            if tokenMidpoint >= segment.startTimeSeconds && tokenMidpoint <= segment.endTimeSeconds {
                return segment.speakerId
            }
        }

        // Fallback: find closest speaker segment
        var closestSpeaker = "SPEAKER_UNKNOWN"
        var minDistance = Float.infinity

        for segment in speakerSegments {
            let distance = min(
                abs(tokenMidpoint - segment.startTimeSeconds),
                abs(tokenMidpoint - segment.endTimeSeconds)
            )
            if distance < minDistance {
                minDistance = distance
                closestSpeaker = segment.speakerId
            }
        }

        return closestSpeaker
    }
}

/// A segment of speech with aligned words and speaker label
struct AlignedSegment {
    let speaker: String
    let start: TimeInterval
    let end: TimeInterval
    let words: [AlignedWord]

    var text: String {
        words.map { $0.word }.joined(separator: " ")
    }
}

/// A single word with timing and speaker information
struct AlignedWord {
    let word: String
    let start: TimeInterval
    let end: TimeInterval
    let score: Float
    let speaker: String
}
