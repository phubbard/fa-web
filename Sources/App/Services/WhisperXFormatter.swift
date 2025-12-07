import Foundation

/// Converts aligned segments into WhisperX JSON format
struct WhisperXFormatter {

    /// Builds WhisperX-compatible JSON from aligned segments
    /// - Parameter segments: Aligned segments with speaker labels and words
    /// - Returns: Dictionary matching WhisperX output format
    func buildWhisperXFormat(from segments: [AlignedSegment]) -> [String: Any] {
        let whisperXSegments = segments.map { segment -> [String: Any] in
            [
                "speaker": segment.speaker,
                "start": segment.start,
                "end": segment.end,
                "text": " " + segment.text.trimmingCharacters(in: .whitespaces),  // WhisperX adds single leading space
                "words": segment.words.map { word -> [String: Any] in
                    [
                        "word": word.word,
                        "start": word.start,
                        "end": word.end,
                        "score": word.score,
                        "speaker": word.speaker
                    ]
                }
            ]
        }

        return [
            "segments": whisperXSegments
        ]
    }

    /// Encodes the WhisperX format as JSON data
    /// - Parameter segments: Aligned segments
    /// - Returns: JSON data ready to write to file or send as response
    func encodeJSON(from segments: [AlignedSegment]) throws -> Data {
        let dict = buildWhisperXFormat(from: segments)
        return try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
    }

    /// Encodes and saves WhisperX JSON to a file
    /// - Parameters:
    ///   - segments: Aligned segments
    ///   - path: File path to save to
    func save(segments: [AlignedSegment], to path: String) throws {
        let data = try encodeJSON(from: segments)
        try data.write(to: URL(fileURLWithPath: path))
    }
}
