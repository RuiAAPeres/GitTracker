import Foundation

protocol ProjectInsightsFetching: Sendable {
    func fetch(projectPath: String) async -> ProjectInsights
}

actor ProjectInsightsService: ProjectInsightsFetching {
    private let commandRunner: CommandRunning
    private let fileManager: FileManager
    private var gitAvailability: Bool?

    init(commandRunner: CommandRunning = ProcessCommandRunner(), fileManager: FileManager = .default) {
        self.commandRunner = commandRunner
        self.fileManager = fileManager
    }

    func fetch(projectPath: String) async -> ProjectInsights {
        guard await ensureGitIsAvailable() else {
            return .unavailable(projectPath: projectPath, errorMessage: "git unavailable")
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: projectPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            return .unavailable(projectPath: projectPath, errorMessage: "path unavailable")
        }

        let repoCheck = commandRunner.run(
            "/usr/bin/env",
            arguments: ["git", "-C", projectPath, "rev-parse", "--is-inside-work-tree"],
            timeout: 4
        )
        guard repoCheck.exitCode == 0 else {
            return .unavailable(projectPath: projectPath, errorMessage: "not a git repository")
        }

        let branchName = fetchBranchName(projectPath: projectPath)
        let workingTree = fetchWorkingTreeStats(projectPath: projectPath)
        let history = fetchHistoryStats(projectPath: projectPath)
        let commitsLast7Days = fetchCommitCount(projectPath: projectPath, since: "7.days")
        let commitsLast30Days = fetchCommitCount(projectPath: projectPath, since: "30.days")

        return ProjectInsights(
            projectPath: projectPath,
            branchName: branchName,
            commitsLast7Days: commitsLast7Days,
            commitsLast30Days: commitsLast30Days,
            averageCommitDeltaLast30Days: history.averageCommitDeltaLast30Days,
            averageFilesPerCommitLast30Days: history.averageFilesPerCommitLast30Days,
            activeCommitDaysLast30Days: history.activeCommitDaysLast30Days,
            workingTreeChangedFiles: workingTree.changedFiles,
            workingTreeAddedLines: workingTree.addedLines,
            workingTreeRemovedLines: workingTree.removedLines,
            available: true,
            errorMessage: nil
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

    private func fetchBranchName(projectPath: String) -> String? {
        let result = commandRunner.run(
            "/usr/bin/env",
            arguments: ["git", "-C", projectPath, "rev-parse", "--abbrev-ref", "HEAD"],
            timeout: 4
        )
        guard result.exitCode == 0, !result.timedOut else {
            return nil
        }
        let branch = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return branch.isEmpty ? nil : branch
    }

    private func fetchCommitCount(projectPath: String, since: String) -> Int {
        let result = commandRunner.run(
            "/usr/bin/env",
            arguments: ["git", "-C", projectPath, "rev-list", "--count", "--since=\(since)", "HEAD"],
            timeout: 5
        )

        guard result.exitCode == 0, !result.timedOut else {
            return 0
        }

        return Int(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private func fetchWorkingTreeStats(projectPath: String) -> (changedFiles: Int, addedLines: Int, removedLines: Int) {
        let result = commandRunner.run(
            "/usr/bin/env",
            arguments: ["git", "-C", projectPath, "diff", "HEAD", "--numstat"],
            timeout: 5
        )

        guard result.exitCode == 0, !result.timedOut else {
            return (0, 0, 0)
        }

        var changedFiles = 0
        var addedLines = 0
        var removedLines = 0

        for line in result.stdout.split(whereSeparator: \.isNewline) {
            let columns = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard columns.count >= 3 else {
                continue
            }
            changedFiles += 1
            if let add = Int(columns[0]) {
                addedLines += add
            }
            if let remove = Int(columns[1]) {
                removedLines += remove
            }
        }

        return (changedFiles, addedLines, removedLines)
    }

    private func fetchHistoryStats(projectPath: String) -> (
        averageCommitDeltaLast30Days: Int,
        averageFilesPerCommitLast30Days: Double,
        activeCommitDaysLast30Days: Int
    ) {
        let result = commandRunner.run(
            "/usr/bin/env",
            arguments: ["git", "-C", projectPath, "log", "--since=30.days", "--date=unix", "--pretty=format:commit:%ct", "--shortstat"],
            timeout: 12
        )

        guard result.exitCode == 0, !result.timedOut else {
            return (0, 0, 0)
        }

        let parsed = Self.parseGitLogShortstat(result.stdout)
        let commitsLast30Days = parsed.commits.count
        guard commitsLast30Days > 0 else {
            return (0, 0, 0)
        }

        let totalDelta = parsed.commits.reduce(0) { $0 + $1.deltaLines }
        let totalFiles = parsed.commits.reduce(0) { $0 + $1.filesChanged }
        let avgDelta = totalDelta / commitsLast30Days
        let avgFiles = Double(totalFiles) / Double(commitsLast30Days)

        return (
            avgDelta,
            avgFiles,
            parsed.activeDays.count
        )
    }

    struct CommitAggregate: Hashable {
        var timestamp: Date
        var deltaLines: Int
        var filesChanged: Int
    }

    static func parseGitLogShortstat(_ input: String) -> (commits: [CommitAggregate], activeDays: Set<String>) {
        var commits: [CommitAggregate] = []
        var currentIndex: Int?
        var activeDays: Set<String> = []

        for rawLine in input.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            if line.hasPrefix("commit:") {
                let epochString = line.dropFirst("commit:".count)
                guard let epochSeconds = TimeInterval(epochString) else {
                    currentIndex = nil
                    continue
                }

                let date = Date(timeIntervalSince1970: epochSeconds)
                commits.append(CommitAggregate(timestamp: date, deltaLines: 0, filesChanged: 0))
                currentIndex = commits.count - 1

                let dayKey = Self.dayFormatter.string(from: date)
                activeDays.insert(dayKey)
                continue
            }

            guard let index = currentIndex else {
                continue
            }

            guard let shortstat = parseShortstat(line) else {
                continue
            }
            commits[index].deltaLines += shortstat.added + shortstat.removed
            commits[index].filesChanged += shortstat.filesChanged
        }

        return (commits, activeDays)
    }

    private static func parseShortstat(_ line: String) -> (filesChanged: Int, added: Int, removed: Int)? {
        guard line.contains("file changed") || line.contains("files changed") else {
            return nil
        }

        let nsLine = line as NSString
        let fullRange = NSRange(location: 0, length: nsLine.length)
        guard let match = shortstatRegex.firstMatch(in: line, options: [], range: fullRange) else {
            return nil
        }

        let filesChanged = Int(nsLine.substring(with: match.range(at: 1))) ?? 0
        let added = match.range(at: 2).location != NSNotFound ? (Int(nsLine.substring(with: match.range(at: 2))) ?? 0) : 0
        let removed = match.range(at: 3).location != NSNotFound ? (Int(nsLine.substring(with: match.range(at: 3))) ?? 0) : 0
        return (filesChanged, added, removed)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let shortstatRegex = try! NSRegularExpression(
        pattern: "(\\d+)\\s+files?\\s+changed(?:,\\s+(\\d+)\\s+insertions?\\(\\+\\))?(?:,\\s+(\\d+)\\s+deletions?\\(-\\))?",
        options: []
    )
}
