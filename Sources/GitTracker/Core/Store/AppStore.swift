import AppKit
import Foundation

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published private(set) var resolvedProjects: [ResolvedProject]
    @Published private(set) var metricsByPath: [String: ProjectMetrics]
    @Published private(set) var alertStates: [String: AlertState]
    @Published private(set) var lastRefreshAt: Date?
    @Published private(set) var isRefreshing: Bool

    private let settingsRepository: SettingsPersisting
    private let projectResolver: ProjectResolving
    private let gitMetricsService: GitMetricsFetching
    private let alertEvaluator: AlertEvaluating
    private let notificationService: NotificationSending

    private var refreshTask: Task<Void, Never>?
    private var hasStarted = false

    init(
        settingsRepository: SettingsPersisting,
        projectResolver: ProjectResolving,
        gitMetricsService: GitMetricsFetching,
        alertEvaluator: AlertEvaluating,
        notificationService: NotificationSending
    ) {
        self.settingsRepository = settingsRepository
        self.projectResolver = projectResolver
        self.gitMetricsService = gitMetricsService
        self.alertEvaluator = alertEvaluator
        self.notificationService = notificationService

        self.settings = .default
        self.resolvedProjects = []
        self.metricsByPath = [:]
        self.alertStates = [:]
        self.lastRefreshAt = nil
        self.isRefreshing = false
    }

    deinit {
        refreshTask?.cancel()
    }

    static func live() -> AppStore {
        AppStore(
            settingsRepository: UserDefaultsSettingsRepository(),
            projectResolver: ProjectResolver(),
            gitMetricsService: GitMetricsService(),
            alertEvaluator: AlertEvaluator(),
            notificationService: NotificationService()
        )
    }

    func startIfNeeded() async {
        guard !hasStarted else {
            return
        }
        hasStarted = true
        settings = settingsRepository.load()
        if settings.notificationsEnabled {
            await notificationService.requestAuthorizationIfNeeded()
        }
        restartRefreshLoop()
        await refreshNow(manual: false)
    }

    var breachedCount: Int {
        alertStates.values.filter(\.isBreached).count
    }

    var menuTitle: String {
        breachedCount > 0 ? "!\(breachedCount)" : "GT"
    }

    var projectRows: [ProjectRow] {
        resolvedProjects.map { project in
            let metrics = metricsByPath[project.path] ?? ProjectMetrics(
                projectPath: project.path,
                addedLines: 0,
                removedLines: 0,
                status: .pathUnavailable,
                lastUpdatedAt: Date()
            )
            let isBreached = alertStates[project.path]?.isBreached == true
            return ProjectRow(
                path: project.path,
                name: project.name,
                addedLines: metrics.addedLines,
                removedLines: metrics.removedLines,
                status: metrics.status,
                isBreached: isBreached
            )
        }.sorted {
            if $0.isBreached != $1.isBreached {
                return $0.isBreached && !$1.isBreached
            }
            if $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedSame {
                return $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func refreshNow(manual: Bool = true) async {
        guard !isRefreshing else {
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }

        let enabledSpecs = settings.projectSpecs.filter(\.enabled)
        let resolved = projectResolver.resolve(specs: enabledSpecs)
        resolvedProjects = resolved

        let chunkedProjects = resolved.chunked(into: 4)
        var newMetrics: [String: ProjectMetrics] = [:]

        for chunk in chunkedProjects {
            await withTaskGroup(of: ProjectMetrics.self) { group in
                for project in chunk {
                    group.addTask {
                        await self.gitMetricsService.fetch(for: project)
                    }
                }
                for await metrics in group {
                    newMetrics[metrics.projectPath] = metrics
                }
            }
        }

        metricsByPath = newMetrics

        let specsByID = Dictionary(uniqueKeysWithValues: settings.projectSpecs.map { ($0.id, $0) })
        let evaluation = alertEvaluator.evaluate(
            projects: resolved,
            metricsByPath: newMetrics,
            specsByID: specsByID,
            globalThreshold: settings.globalThreshold,
            previousStates: alertStates,
            now: Date()
        )

        alertStates = evaluation.states
        lastRefreshAt = Date()

        if settings.notificationsEnabled {
            for path in evaluation.newlyBreachedPaths {
                guard
                    let project = resolved.first(where: { $0.path == path }),
                    let metrics = newMetrics[path],
                    let state = alertStates[path],
                    state.isBreached
                else {
                    continue
                }
                await notificationService.sendBreachNotification(
                    projectName: project.name,
                    metrics: metrics,
                    reasons: state.breachReasons
                )
            }
        }

        if manual {
            settingsRepository.save(settings)
        }
    }

    func addProject(from rawInput: String) {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        let input: ProjectInput
        if trimmed.hasSuffix("/*") {
            let root = String(trimmed.dropLast(2)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !root.isEmpty else {
                return
            }
            input = .childrenOf(path: root)
        } else {
            input = .exact(path: trimmed)
        }

        let newSpec = ProjectSpec(input: input)
        if settings.projectSpecs.contains(where: { $0.input == newSpec.input }) {
            return
        }

        settings.projectSpecs.append(newSpec)
        persistSettingsAndRefreshLoop()
        Task { await refreshNow(manual: false) }
    }

    func removeProject(id: UUID) {
        settings.projectSpecs.removeAll { $0.id == id }
        persistSettingsAndRefreshLoop()
        Task { await refreshNow(manual: false) }
    }

    func setProjectEnabled(id: UUID, enabled: Bool) {
        guard let index = settings.projectSpecs.firstIndex(where: { $0.id == id }) else {
            return
        }
        settings.projectSpecs[index].enabled = enabled
        persistSettingsAndRefreshLoop()
        Task { await refreshNow(manual: false) }
    }

    func setProjectNameOverride(id: UUID, nameOverride: String?) {
        guard let index = settings.projectSpecs.firstIndex(where: { $0.id == id }) else {
            return
        }
        let value = nameOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.projectSpecs[index].nameOverride = (value?.isEmpty == true) ? nil : value
        persistSettingsAndRefreshLoop()
        Task { await refreshNow(manual: false) }
    }

    func setProjectThresholdOverride(id: UUID, threshold: ThresholdRule?) {
        guard let index = settings.projectSpecs.firstIndex(where: { $0.id == id }) else {
            return
        }
        settings.projectSpecs[index].thresholdOverride = threshold
        persistSettingsAndRefreshLoop()
        Task { await refreshNow(manual: false) }
    }

    func setGlobalThreshold(_ threshold: ThresholdRule) {
        settings.globalThreshold = threshold
        persistSettingsAndRefreshLoop()
        Task { await refreshNow(manual: false) }
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        settings.notificationsEnabled = enabled
        persistSettingsAndRefreshLoop()
        if enabled {
            Task { await notificationService.requestAuthorizationIfNeeded() }
        }
    }

    func setRefreshInterval(_ interval: RefreshInterval) {
        settings.refreshInterval = interval
        persistSettingsAndRefreshLoop()
        Task { await refreshNow(manual: false) }
    }

    func revealProjectInFinder(path: String) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }

    private func persistSettingsAndRefreshLoop() {
        settingsRepository.save(settings)
        restartRefreshLoop()
    }

    private func restartRefreshLoop() {
        refreshTask?.cancel()
        guard let intervalSeconds = settings.refreshInterval.seconds else {
            refreshTask = nil
            return
        }

        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(intervalSeconds))
                guard !Task.isCancelled else {
                    return
                }
                await self?.refreshNow(manual: false)
            }
        }
    }
}

private extension Array {
    func chunked(into chunkSize: Int) -> [[Element]] {
        guard chunkSize > 0 else {
            return [self]
        }
        var chunks: [[Element]] = []
        chunks.reserveCapacity((count / chunkSize) + 1)
        var index = 0
        while index < count {
            let end = Swift.min(index + chunkSize, count)
            chunks.append(Array(self[index..<end]))
            index += chunkSize
        }
        return chunks
    }
}
