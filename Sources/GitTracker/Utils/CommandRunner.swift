import Foundation

struct CommandResult: Sendable {
    var exitCode: Int32
    var stdout: String
    var stderr: String
    var timedOut: Bool
}

protocol CommandRunning {
    func run(_ executable: String, arguments: [String], timeout: TimeInterval?) -> CommandResult
}

struct ProcessCommandRunner: CommandRunning {
    func run(_ executable: String, arguments: [String], timeout: TimeInterval? = nil) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            return CommandResult(exitCode: 127, stdout: "", stderr: error.localizedDescription, timedOut: false)
        }

        let timedOut: Bool
        if let timeout {
            let deadline = Date().addingTimeInterval(timeout)
            while process.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
            if process.isRunning {
                process.terminate()
                timedOut = true
            } else {
                timedOut = false
            }
        } else {
            timedOut = false
        }

        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return CommandResult(
            exitCode: process.terminationStatus,
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? "",
            timedOut: timedOut
        )
    }
}
