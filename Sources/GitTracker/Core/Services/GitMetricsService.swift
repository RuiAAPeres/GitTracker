import Foundation

protocol GitMetricsFetching: Sendable {
    func fetch(for project: ResolvedProject) async -> ProjectMetrics
}

actor GitMetricsService: GitMetricsFetching {
    private let commandRunner: CommandRunning
    private let fileManager: FileManager
    private var gitAvailability: Bool?

    init(commandRunner: CommandRunning = ProcessCommandRunner(), fileManager: FileManager = .default) {
        self.commandRunner = commandRunner
        self.fileManager = fileManager
    }

    func fetch(for project: ResolvedProject) async -> ProjectMetrics {
        guard await ensureGitIsAvailable() else {
            return ProjectMetrics(
                projectPath: project.path,
                addedLines: 0,
                removedLines: 0,
                status: .gitUnavailable,
                lastUpdatedAt: Date()
            )
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: project.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return ProjectMetrics(
                projectPath: project.path,
                addedLines: 0,
                removedLines: 0,
                status: .pathUnavailable,
                lastUpdatedAt: Date()
            )
        }

        let repoCheck = commandRunner.run(
            "/usr/bin/env",
            arguments: ["git", "-C", project.path, "rev-parse", "--is-inside-work-tree"],
            timeout: 5
        )
        guard repoCheck.exitCode == 0 else {
            return ProjectMetrics(
                projectPath: project.path,
                addedLines: 0,
                removedLines: 0,
                status: .notRepo,
                lastUpdatedAt: Date()
            )
        }

        let diffResult = commandRunner.run(
            "/usr/bin/env",
            arguments: ["git", "-C", project.path, "diff", "HEAD", "--numstat"],
            timeout: 5
        )

        guard diffResult.exitCode == 0, !diffResult.timedOut else {
            let message = diffResult.timedOut ? "git command timed out" : diffResult.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return ProjectMetrics(
                projectPath: project.path,
                addedLines: 0,
                removedLines: 0,
                status: .error(message.isEmpty ? "unknown git error" : message),
                lastUpdatedAt: Date()
            )
        }

        let (addedLines, removedLines) = Self.parseNumstat(diffResult.stdout)
        return ProjectMetrics(
            projectPath: project.path,
            addedLines: addedLines,
            removedLines: removedLines,
            status: .ok,
            lastUpdatedAt: Date()
        )
    }

    private func ensureGitIsAvailable() async -> Bool {
        if let gitAvailability {
            return gitAvailability
        }
        let result = commandRunner.run("/usr/bin/env", arguments: ["git", "--version"], timeout: 3)
        let available = result.exitCode == 0
        gitAvailability = available
        return available
    }

    static func parseNumstat(_ input: String) -> (added: Int, removed: Int) {
        var added = 0
        var removed = 0

        for line in input.split(whereSeparator: \.isNewline) {
            let columns = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard columns.count >= 3 else {
                continue
            }
            if let addValue = Int(columns[0]) {
                added += addValue
            }
            if let removeValue = Int(columns[1]) {
                removed += removeValue
            }
        }

        return (added, removed)
    }
}
