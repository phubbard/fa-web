import Foundation

struct BuildInfo {
    static var buildTimestamp: String {
        // Get the App binary's modification time
        let binaryPath = "/Users/pfh/code/fa-web/.build/release/App"
        if let attributes = try? FileManager.default.attributesOfItem(atPath: binaryPath),
           let modDate = attributes[.modificationDate] as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: modDate)
        }
        return "unknown"
    }

    static var fluidAudioVersion: String {
        // Get the FluidAudio git commit hash
        let fluidAudioPath = "/Users/pfh/code/FluidAudio"
        let task = Process()
        task.currentDirectoryURL = URL(fileURLWithPath: fluidAudioPath)
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["rev-parse", "--short", "HEAD"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !output.isEmpty {
                return output
            }
        } catch {
            return "unknown"
        }

        return "unknown"
    }

    static var fluidAudioDate: String {
        // Get the last commit date from FluidAudio
        let fluidAudioPath = "/Users/pfh/code/FluidAudio"
        let task = Process()
        task.currentDirectoryURL = URL(fileURLWithPath: fluidAudioPath)
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["log", "-1", "--format=%cd", "--date=short"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !output.isEmpty {
                return output
            }
        } catch {
            return ""
        }

        return ""
    }
}
