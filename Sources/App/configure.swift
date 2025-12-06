import Vapor
import Fluent
import FluentSQLiteDriver
import Leaf

// Configure the application
public func configure(_ app: Application) throws {
    // Bind to all interfaces on port 5051 (matching Flask app)
    app.http.server.configuration.hostname = "0.0.0.0"
    app.http.server.configuration.port = 5051

    // Increase max body size for large audio files (500MB)
    app.routes.defaultMaxBodySize = "500mb"

    // Configure SQLite database
    app.databases.use(.sqlite(.file("fa-web.db")), as: .sqlite)

    // Add migrations
    app.migrations.add(CreateJob())
    app.migrations.add(CreateLog())

    // Configure Leaf templating
    app.views.use(.leaf)

    // Serve static files from Public directory
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // Register routes
    try routes(app)

    // Run migrations automatically
    try app.autoMigrate().wait()
}
