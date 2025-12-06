import Fluent

struct CreateJob: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("jobs")
            .field("id", .uuid, .identifier(auto: false))
            .field("timestamp", .datetime)
            .field("podcast", .string, .required)
            .field("episode_number", .string, .required)
            .field("job_id", .string, .required)
            .field("elapsed", .int, .required)
            .field("status", .string, .required)
            .field("return_code", .int)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("jobs").delete()
    }
}
