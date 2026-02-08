import Fluent

struct AddOutputPath: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("jobs")
            .field("output_path", .string)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("jobs")
            .deleteField("output_path")
            .update()
    }
}
