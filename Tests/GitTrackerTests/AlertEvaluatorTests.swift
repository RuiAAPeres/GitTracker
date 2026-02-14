import Foundation
import Testing
@testable import GitTracker

struct AlertEvaluatorTests {
    @Test
    func globalThresholdBreachAndTransition() {
        let evaluator = AlertEvaluator()

        let spec = ProjectSpec(input: .exact(path: "/tmp/repo"))
        let project = ResolvedProject(sourceSpecID: spec.id, name: "repo", path: "/tmp/repo", isGitRepo: true)
        let metrics = ProjectMetrics(projectPath: "/tmp/repo", addedLines: 250, removedLines: 10, status: .ok, lastCommitAt: nil, lastUpdatedAt: Date())

        let result = evaluator.evaluate(
            projects: [project],
            metricsByPath: [project.path: metrics],
            specsByID: [spec.id: spec],
            globalThreshold: .v1Default,
            previousStates: [:],
            now: Date()
        )

        #expect(result.newlyBreachedPaths == [project.path])
        #expect(result.states[project.path]?.isBreached == true)
    }

    @Test
    func projectOverridePrecedence() {
        let evaluator = AlertEvaluator()

        let override = ThresholdRule(maxAddedLines: 500, maxRemovedLines: 500, maxTotalDelta: 700)
        let spec = ProjectSpec(input: .exact(path: "/tmp/repo"), thresholdOverride: override)
        let project = ResolvedProject(sourceSpecID: spec.id, name: "repo", path: "/tmp/repo", isGitRepo: true)
        let metrics = ProjectMetrics(projectPath: "/tmp/repo", addedLines: 250, removedLines: 10, status: .ok, lastCommitAt: nil, lastUpdatedAt: Date())

        let result = evaluator.evaluate(
            projects: [project],
            metricsByPath: [project.path: metrics],
            specsByID: [spec.id: spec],
            globalThreshold: .v1Default,
            previousStates: [:],
            now: Date()
        )

        #expect(result.newlyBreachedPaths.isEmpty)
        #expect(result.states[project.path]?.isBreached == false)
    }

    @Test
    func transitionOnlyFiresOnceUntilResolved() {
        let evaluator = AlertEvaluator()

        let spec = ProjectSpec(input: .exact(path: "/tmp/repo"))
        let project = ResolvedProject(sourceSpecID: spec.id, name: "repo", path: "/tmp/repo", isGitRepo: true)
        let metrics = ProjectMetrics(projectPath: "/tmp/repo", addedLines: 250, removedLines: 10, status: .ok, lastCommitAt: nil, lastUpdatedAt: Date())

        let first = evaluator.evaluate(
            projects: [project],
            metricsByPath: [project.path: metrics],
            specsByID: [spec.id: spec],
            globalThreshold: .v1Default,
            previousStates: [:],
            now: Date()
        )

        let second = evaluator.evaluate(
            projects: [project],
            metricsByPath: [project.path: metrics],
            specsByID: [spec.id: spec],
            globalThreshold: .v1Default,
            previousStates: first.states,
            now: Date().addingTimeInterval(60)
        )

        #expect(first.newlyBreachedPaths == [project.path])
        #expect(second.newlyBreachedPaths.isEmpty)
    }
}
