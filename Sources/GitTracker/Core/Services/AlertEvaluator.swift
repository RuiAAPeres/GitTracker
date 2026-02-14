import Foundation

struct AlertEvaluationResult: Sendable {
    var states: [String: AlertState]
    var newlyBreachedPaths: [String]
}

protocol AlertEvaluating {
    func evaluate(
        projects: [ResolvedProject],
        metricsByPath: [String: ProjectMetrics],
        specsByID: [UUID: ProjectSpec],
        globalThreshold: ThresholdRule,
        previousStates: [String: AlertState],
        now: Date
    ) -> AlertEvaluationResult
}

struct AlertEvaluator: AlertEvaluating {
    func evaluate(
        projects: [ResolvedProject],
        metricsByPath: [String: ProjectMetrics],
        specsByID: [UUID: ProjectSpec],
        globalThreshold: ThresholdRule,
        previousStates: [String: AlertState],
        now: Date
    ) -> AlertEvaluationResult {
        var states: [String: AlertState] = [:]
        var newlyBreached: [String] = []

        for project in projects {
            guard let metrics = metricsByPath[project.path] else {
                continue
            }
            let threshold = specsByID[project.sourceSpecID]?.thresholdOverride ?? globalThreshold
            let reasons = threshold.breachReasons(for: metrics)
            let isBreached = !reasons.isEmpty
            let previous = previousStates[project.path]
            let hasTransition = previous?.isBreached != isBreached

            if isBreached && previous?.isBreached != true {
                newlyBreached.append(project.path)
            }

            states[project.path] = AlertState(
                projectPath: project.path,
                isBreached: isBreached,
                breachReasons: reasons,
                lastTransitionAt: hasTransition ? now : previous?.lastTransitionAt,
                notificationSentForCurrentBreach: isBreached && previous?.isBreached == true
            )
        }

        return AlertEvaluationResult(states: states, newlyBreachedPaths: newlyBreached)
    }
}
