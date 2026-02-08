import Vapor
import Fluent

func routes(_ app: Application) throws {
    let controller = WebController()

    // Web UI routes
    app.get(use: controller.index)
    app.get("job", ":jobId", use: controller.jobDetail)
    app.post("cleanup", use: controller.cleanup)

    // REST API routes
    app.post("submit", ":podcast", ":episodeNumber", use: controller.submit)
    app.get("result", ":jobId", use: controller.result)
}
