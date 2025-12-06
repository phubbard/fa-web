import Fluent
import Vapor

final class JobLog: Model, Content {
    static let schema = "logs"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "job_id")
    var job: Job

    @Timestamp(key: "timestamp", on: .create)
    var timestamp: Date?

    @Field(key: "message")
    var message: String

    init() { }

    init(id: UUID? = nil, jobID: UUID, message: String) {
        self.id = id
        self.$job.id = jobID
        self.message = message
    }

    var formattedMessage: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timeString = timestamp.map { formatter.string(from: $0) } ?? "unknown"
        return "\(timeString) \(message)"
    }
}
