import Fluent
import Vapor

final class Job: Model, Content {
    static let schema = "jobs"

    @ID(custom: "id", generatedBy: .user)
    var id: UUID?

    @Timestamp(key: "timestamp", on: .create)
    var timestamp: Date?

    @Field(key: "podcast")
    var podcast: String

    @Field(key: "episode_number")
    var episodeNumber: String

    @Field(key: "job_id")
    var jobId: String

    @Field(key: "elapsed")
    var elapsed: Int

    @Enum(key: "status")
    var status: JobStatus

    @OptionalField(key: "return_code")
    var returnCode: Int?

    @OptionalField(key: "output_path")
    var outputPath: String?

    @Children(for: \.$job)
    var logs: [JobLog]

    init() { }

    init(id: UUID? = nil, podcast: String, episodeNumber: String, jobId: String, status: JobStatus = .new) {
        self.id = id
        self.podcast = podcast
        self.episodeNumber = episodeNumber
        self.jobId = jobId
        self.elapsed = 0
        self.status = status
    }
}

enum JobStatus: String, Codable {
    case new = "NEW"
    case running = "RUNNING"
    case done = "DONE"
    case failed = "FAILED"
}

// Extension for computed properties
extension Job {
    var timeAgo: String {
        guard let timestamp = timestamp else { return "unknown" }
        let now = Date()
        let diff = Calendar.current.dateComponents([.day, .hour, .minute], from: timestamp, to: now)

        if let days = diff.day, days > 0 {
            return "\(days)d ago"
        } else if let hours = diff.hour, hours > 0 {
            return "\(hours)h ago"
        } else if let minutes = diff.minute, minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "just now"
        }
    }

    var durationString: String? {
        guard status == .done, elapsed > 0 else { return nil }

        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        let seconds = elapsed % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}
