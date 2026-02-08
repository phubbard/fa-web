import Vapor
import Fluent

struct WebController {
    // GET / - Main page showing job list
    func index(req: Request) async throws -> View {
        let jobs = try await Job.query(on: req.db)
            .sort(\.$timestamp, .descending)
            .limit(20)
            .all()

        struct Context: Encodable {
            let jobs: [JobContext]
            let buildTimestamp: String
            let fluidAudioVersion: String
            let fluidAudioDate: String
        }

        struct JobContext: Encodable {
            let id: String
            let timestamp: String
            let timeAgo: String
            let podcast: String
            let episodeNumber: String
            let status: String
            let duration: String?
            let jobId: String
        }

        let jobContexts = jobs.map { job in
            JobContext(
                id: job.id?.uuidString ?? "",
                timestamp: formatTimestamp(job.timestamp),
                timeAgo: job.timeAgo,
                podcast: job.podcast,
                episodeNumber: job.episodeNumber,
                status: job.status.rawValue,
                duration: job.durationString,
                jobId: job.jobId
            )
        }

        let context = Context(
            jobs: jobContexts,
            buildTimestamp: BuildInfo.buildTimestamp,
            fluidAudioVersion: BuildInfo.fluidAudioVersion,
            fluidAudioDate: BuildInfo.fluidAudioDate
        )

        return try await req.view.render("index", context)
    }

    // GET /job/:jobId - Job detail page
    func jobDetail(req: Request) async throws -> View {
        guard let jobId = req.parameters.get("jobId") else {
            throw Abort(.badRequest)
        }

        guard let job = try await Job.query(on: req.db)
            .filter(\.$jobId == jobId)
            .first()
        else {
            throw Abort(.notFound)
        }

        let logs = try await JobLog.query(on: req.db)
            .filter(\.$job.$id == job.id!)
            .sort(\.$timestamp, .ascending)
            .all()

        struct Context: Encodable {
            let jobId: String
            let podcast: String
            let episodeNumber: String
            let status: String
            let logs: [String]
        }

        let context = Context(
            jobId: jobId,
            podcast: job.podcast,
            episodeNumber: job.episodeNumber,
            status: job.status.rawValue,
            logs: logs.map { $0.formattedMessage }
        )

        return try await req.view.render("job", context)
    }

    // POST /submit/:podcast/:episodeNumber - Submit new transcription job
    // Returns job ID immediately; client polls /result/:jobId for output
    func submit(req: Request) async throws -> Response {
        guard let podcast = req.parameters.get("podcast"),
              let episodeNumber = req.parameters.get("episodeNumber")
        else {
            throw Abort(.badRequest, reason: "Missing podcast or episode number")
        }

        guard let fileData = try? req.content.decode(FileUpload.self) else {
            throw Abort(.badRequest, reason: "No file uploaded")
        }

        var data = fileData.file.data

        // Generate job ID
        let jobId = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let jobUUID = UUID()

        // Save uploaded file
        let tempPath = "/tmp/\(jobId).mp3"
        let fileURL = URL(fileURLWithPath: tempPath)

        // Convert ByteBuffer to Data properly
        guard let bytes = data.readBytes(length: data.readableBytes) else {
            throw Abort(.badRequest, reason: "Failed to read file data")
        }
        try Data(bytes).write(to: fileURL)

        // Create job in database
        let job = Job(id: jobUUID, podcast: podcast, episodeNumber: episodeNumber, jobId: jobId, status: .new)
        try await job.create(on: req.db)

        // Log job creation
        let logEntry = JobLog(jobID: jobUUID, message: "Job created for \(podcast) episode \(episodeNumber)")
        try await logEntry.create(on: req.db)

        // Kick off processing in the background
        let app = req.application
        Task {
            let processor = AudioProcessingService()
            let startTime = Date()

            do {
                // Re-fetch the job using a fresh db reference from the app
                guard let job = try await Job.find(jobUUID, on: app.db) else { return }

                job.status = .running
                try await job.update(on: app.db)

                let outputPath = try await processor.processAudio(
                    audioPath: tempPath,
                    jobID: jobUUID,
                    podcast: podcast,
                    episodeNumber: episodeNumber,
                    on: app.db
                )

                job.status = .done
                job.elapsed = Int(Date().timeIntervalSince(startTime))
                job.returnCode = 0
                job.outputPath = outputPath
                try await job.update(on: app.db)

                let completionLog = JobLog(jobID: jobUUID, message: "Processing complete. Output: \(outputPath)")
                try await completionLog.create(on: app.db)

                // Clean up uploaded file (output file kept until client fetches it)
                try? FileManager.default.removeItem(atPath: tempPath)

            } catch {
                if let job = try? await Job.find(jobUUID, on: app.db) {
                    job.status = .failed
                    job.returnCode = 1
                    try? await job.update(on: app.db)
                }

                let errorLog = JobLog(jobID: jobUUID, message: "ERROR: \(error.localizedDescription)")
                try? await errorLog.create(on: app.db)

                try? FileManager.default.removeItem(atPath: tempPath)
            }
        }

        // Return job ID immediately
        let responseJSON: [String: String] = ["jobId": jobId, "status": "RUNNING"]
        let responseData = try JSONEncoder().encode(responseJSON)
        return Response(
            status: .accepted,
            headers: ["Content-Type": "application/json"],
            body: .init(data: responseData)
        )
    }

    // GET /result/:jobId - Fetch transcription result
    func result(req: Request) async throws -> Response {
        guard let jobId = req.parameters.get("jobId") else {
            throw Abort(.badRequest, reason: "Missing job ID")
        }

        guard let job = try await Job.query(on: req.db)
            .filter(\.$jobId == jobId)
            .first()
        else {
            throw Abort(.notFound, reason: "Job not found")
        }

        switch job.status {
        case .new, .running:
            let responseJSON: [String: String] = ["jobId": jobId, "status": job.status.rawValue]
            let responseData = try JSONEncoder().encode(responseJSON)
            return Response(
                status: .custom(code: 202, reasonPhrase: "Accepted"),
                headers: ["Content-Type": "application/json"],
                body: .init(data: responseData)
            )

        case .done:
            guard let outputPath = job.outputPath,
                  FileManager.default.fileExists(atPath: outputPath)
            else {
                throw Abort(.internalServerError, reason: "Output file missing")
            }

            return try await req.fileio.asyncStreamFile(at: outputPath, mediaType: .json) { _ in
                // Clean up output file after streaming
                try? FileManager.default.removeItem(atPath: outputPath)
            }

        case .failed:
            throw Abort(.internalServerError, reason: "Transcription failed")
        }
    }

    // POST /cleanup - Clean up stuck running jobs
    func cleanup(req: Request) async throws -> Response {
        let runningJobs = try await Job.query(on: req.db)
            .filter(\.$status == .running)
            .all()

        for job in runningJobs {
            try await job.delete(on: req.db)
        }

        return req.redirect(to: "/")
    }

    // Helper function to format timestamps
    private func formatTimestamp(_ date: Date?) -> String {
        guard let date = date else { return "unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// File upload structure
struct FileUpload: Content {
    var file: File
}
