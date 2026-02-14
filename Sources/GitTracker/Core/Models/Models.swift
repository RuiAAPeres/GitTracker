import Foundation

enum ProjectInput: Hashable, Sendable, Codable {
    case exact(path: String)
    case childrenOf(path: String)

    private enum CodingKeys: String, CodingKey {
        case kind
        case path
    }

    private enum Kind: String, Codable {
        case exact
        case childrenOf
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        let path = try container.decode(String.self, forKey: .path)
        switch kind {
        case .exact:
            self = .exact(path: path)
        case .childrenOf:
            self = .childrenOf(path: path)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .exact(let path):
            try container.encode(Kind.exact, forKey: .kind)
            try container.encode(path, forKey: .path)
        case .childrenOf(let path):
            try container.encode(Kind.childrenOf, forKey: .kind)
            try container.encode(path, forKey: .path)
        }
    }

    var path: String {
        switch self {
        case .exact(let path), .childrenOf(let path):
            return path
        }
    }

    var displayValue: String {
        switch self {
        case .exact(let path):
            return path
        case .childrenOf(let path):
            return "\(path)/*"
        }
    }
}

struct ThresholdRule: Hashable, Sendable, Codable {
    var maxAddedLines: Int?
    var maxRemovedLines: Int?
    var maxTotalDelta: Int?

    static let v1Default = ThresholdRule(maxAddedLines: 200, maxRemovedLines: 200, maxTotalDelta: 300)

    func breachReasons(for metrics: ProjectMetrics) -> [BreachReason] {
        guard metrics.status == .ok else {
            return []
        }

        var reasons: [BreachReason] = []

        if let maxAddedLines, metrics.addedLines > maxAddedLines {
            reasons.append(.added(actual: metrics.addedLines, max: maxAddedLines))
        }
        if let maxRemovedLines, metrics.removedLines > maxRemovedLines {
            reasons.append(.removed(actual: metrics.removedLines, max: maxRemovedLines))
        }
        if let maxTotalDelta, metrics.totalDelta > maxTotalDelta {
            reasons.append(.total(actual: metrics.totalDelta, max: maxTotalDelta))
        }

        return reasons
    }
}

enum BreachReason: Hashable, Sendable {
    case added(actual: Int, max: Int)
    case removed(actual: Int, max: Int)
    case total(actual: Int, max: Int)

    var shortDescription: String {
        switch self {
        case .added(let actual, let max):
            return "+\(actual) > +\(max)"
        case .removed(let actual, let max):
            return "-\(actual) > -\(max)"
        case .total(let actual, let max):
            return "total \(actual) > \(max)"
        }
    }
}

struct ProjectSpec: Identifiable, Hashable, Sendable, Codable {
    var id: UUID
    var nameOverride: String?
    var input: ProjectInput
    var enabled: Bool
    var thresholdOverride: ThresholdRule?

    init(
        id: UUID = UUID(),
        nameOverride: String? = nil,
        input: ProjectInput,
        enabled: Bool = true,
        thresholdOverride: ThresholdRule? = nil
    ) {
        self.id = id
        self.nameOverride = nameOverride
        self.input = input
        self.enabled = enabled
        self.thresholdOverride = thresholdOverride
    }
}

struct ResolvedProject: Identifiable, Hashable, Sendable {
    var id: String { path }
    var sourceSpecID: UUID
    var name: String
    var path: String
    var isGitRepo: Bool
}

enum MetricsStatus: Hashable, Sendable, Codable {
    case ok
    case gitUnavailable
    case notRepo
    case pathUnavailable
    case error(String)
}

struct ProjectMetrics: Identifiable, Hashable, Sendable {
    var id: String { projectPath }
    var projectPath: String
    var addedLines: Int
    var removedLines: Int
    var status: MetricsStatus
    var lastCommitAt: Date?
    var lastUpdatedAt: Date

    var totalDelta: Int {
        addedLines + removedLines
    }
}

struct AlertState: Hashable, Sendable {
    var projectPath: String
    var isBreached: Bool
    var breachReasons: [BreachReason]
    var lastTransitionAt: Date?
    var notificationSentForCurrentBreach: Bool
}

enum RefreshInterval: String, CaseIterable, Codable, Sendable {
    case manual
    case oneMinute
    case twoMinutes
    case fiveMinutes
    case fifteenMinutes

    var seconds: TimeInterval? {
        switch self {
        case .manual:
            return nil
        case .oneMinute:
            return 60
        case .twoMinutes:
            return 120
        case .fiveMinutes:
            return 300
        case .fifteenMinutes:
            return 900
        }
    }

    var label: String {
        switch self {
        case .manual:
            return "Manual"
        case .oneMinute:
            return "Every 1 minute"
        case .twoMinutes:
            return "Every 2 minutes"
        case .fiveMinutes:
            return "Every 5 minutes"
        case .fifteenMinutes:
            return "Every 15 minutes"
        }
    }
}

struct AppSettings: Hashable, Sendable, Codable {
    var projectSpecs: [ProjectSpec]
    var globalThreshold: ThresholdRule
    var notificationsEnabled: Bool
    var refreshInterval: RefreshInterval

    static let `default` = AppSettings(
        projectSpecs: [],
        globalThreshold: .v1Default,
        notificationsEnabled: true,
        refreshInterval: .twoMinutes
    )
}

struct ProjectRow: Identifiable, Hashable, Sendable {
    var id: String { path }
    var path: String
    var name: String
    var addedLines: Int
    var removedLines: Int
    var status: MetricsStatus
    var lastCommitAt: Date?
    var isBreached: Bool
}
