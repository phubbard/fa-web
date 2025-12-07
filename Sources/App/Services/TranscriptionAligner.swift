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

        // First pass: assign speakers to all words
        var wordsWithSpeakers: [(word: AlignedWord, speaker: String)] = []
        for token in tokenTimings {
            let speaker = findSpeaker(for: token, in: speakerSegments)
            let word = AlignedWord(
                word: token.token,
                start: token.startTime,
                end: token.endTime,
                score: token.confidence,
                speaker: speaker
            )
            wordsWithSpeakers.append((word, speaker))
        }

        // Second pass: smooth speaker boundaries with minimum segment duration
        // This prevents single-word speaker changes which are usually diarization errors
        let minSegmentDuration: TimeInterval = 2.0  // Minimum 2 seconds per segment

        var currentSegments: [AlignedSegment] = []
        var currentSpeaker: String? = nil
        var currentWords: [AlignedWord] = []
        var currentStart: TimeInterval? = nil
        var currentEnd: TimeInterval = 0

        for (word, speaker) in wordsWithSpeakers {
            // If speaker changed, check if we should commit the current segment
            if let prevSpeaker = currentSpeaker, speaker != prevSpeaker, !currentWords.isEmpty {
                let duration = currentEnd - (currentStart ?? 0)

                // Only create new segment if current segment is long enough
                // This prevents fragmenting sentences due to brief diarization errors
                if duration >= minSegmentDuration {
                    let segment = AlignedSegment(
                        speaker: prevSpeaker,
                        start: currentStart ?? word.start,
                        end: currentEnd,
                        words: currentWords
                    )
                    currentSegments.append(segment)
                    currentWords = []
                    currentStart = nil
                    currentSpeaker = speaker
                }
                // Otherwise, keep accumulating words with the previous speaker
                // (ignore brief speaker changes)
            }

            // Add word to current segment
            if currentSpeaker == nil {
                currentSpeaker = speaker
            }
            if currentStart == nil {
                currentStart = word.start
            }
            currentEnd = word.end
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
        // SentencePiece tokens already have leading spaces where appropriate
        // Simply concatenate without adding extra separators
        words.map { $0.word }.joined()
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
