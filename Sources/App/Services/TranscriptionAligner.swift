import Foundation
import FluidAudio

/// Aligns ASR word timings with diarization speaker segments
struct TranscriptionAligner {

    /// Aligns words from ASR with speakers from diarization
    /// - Parameters:
    ///   - asrResult: ASR result with token-level timings
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

        // Aggregate sub-word tokens into whole words before speaker assignment.
        // Otherwise a diarization boundary landing mid-word splits a single word
        // across two speakers (e.g. "bump" → "b" / "ump").
        let words = buildWords(from: tokenTimings, speakerSegments: speakerSegments)

        // Smooth speaker boundaries with a minimum segment duration to ignore
        // very brief diarization glitches.
        let minSegmentDuration: TimeInterval = 2.0

        var currentSegments: [AlignedSegment] = []
        var currentSpeaker: String? = nil
        var currentWords: [AlignedWord] = []
        var currentStart: TimeInterval? = nil
        var currentEnd: TimeInterval = 0

        for word in words {
            let speaker = word.speaker
            if let prevSpeaker = currentSpeaker, speaker != prevSpeaker, !currentWords.isEmpty {
                let duration = currentEnd - (currentStart ?? 0)
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
            }

            if currentSpeaker == nil { currentSpeaker = speaker }
            if currentStart == nil { currentStart = word.start }
            currentEnd = word.end
            currentWords.append(word)
        }

        if !currentWords.isEmpty, let speaker = currentSpeaker, let start = currentStart {
            currentSegments.append(AlignedSegment(
                speaker: speaker,
                start: start,
                end: currentEnd,
                words: currentWords
            ))
        }

        return currentSegments
    }

    /// Groups consecutive sub-word tokens into whole words and assigns each
    /// whole word the speaker with the greatest temporal overlap. SentencePiece
    /// rule: tokens starting with " " or "▁" begin a new word.
    private func buildWords(
        from tokenTimings: [TokenTiming],
        speakerSegments: [TimedSpeakerSegment]
    ) -> [AlignedWord] {
        var words: [AlignedWord] = []
        var buffer: [TokenTiming] = []

        func flush() {
            guard !buffer.isEmpty else { return }
            let text = buffer.map(\.token).joined()
            let start = buffer.first!.startTime
            let end = buffer.last!.endTime
            let scoreSum = buffer.reduce(Float(0)) { $0 + $1.confidence }
            let score = scoreSum / Float(buffer.count)
            let speaker = bestSpeaker(start: start, end: end, in: speakerSegments)
            words.append(AlignedWord(word: text, start: start, end: end, score: score, speaker: speaker))
            buffer.removeAll(keepingCapacity: true)
        }

        for token in tokenTimings {
            let startsNewWord = token.token.hasPrefix(" ") || token.token.hasPrefix("\u{2581}")
            if startsNewWord && !buffer.isEmpty {
                flush()
            }
            buffer.append(token)
        }
        flush()
        return words
    }

    /// Returns the speaker whose segment has the greatest temporal overlap
    /// with [start, end]. Falls back to the nearest segment if there is no overlap.
    private func bestSpeaker(
        start: TimeInterval,
        end: TimeInterval,
        in speakerSegments: [TimedSpeakerSegment]
    ) -> String {
        let wordStart = Float(start)
        let wordEnd = Float(end)
        var best = "SPEAKER_UNKNOWN"
        var bestOverlap: Float = 0

        for segment in speakerSegments {
            let overlap = min(wordEnd, segment.endTimeSeconds) - max(wordStart, segment.startTimeSeconds)
            if overlap > bestOverlap {
                bestOverlap = overlap
                best = segment.speakerId
            }
        }
        if bestOverlap > 0 { return best }

        let midpoint = (wordStart + wordEnd) / 2
        var minDistance = Float.infinity
        for segment in speakerSegments {
            let distance = min(
                abs(midpoint - segment.startTimeSeconds),
                abs(midpoint - segment.endTimeSeconds)
            )
            if distance < minDistance {
                minDistance = distance
                best = segment.speakerId
            }
        }
        return best
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
