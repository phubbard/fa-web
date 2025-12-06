import Fluent

struct CreateLog: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("logs")
            .id()
            .field("job_id", .uuid, .required, .references("jobs", "id", onDelete: .cascade))
            .field("timestamp", .datetime)
            .field("message", .string, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("logs").delete()
    }
}
