import Foundation
import Testing
@testable import GitTracker

struct SettingsRepositoryTests {
    @Test
    func roundTripSettings() {
        let suiteName = "gittracker-tests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create isolated UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        let repository = UserDefaultsSettingsRepository(defaults: defaults, key: "settings")

        let settings = AppSettings(
            projectSpecs: [
                ProjectSpec(
                    id: UUID(),
                    nameOverride: "Project A",
                    input: .exact(path: "/tmp/a"),
                    enabled: true,
                    thresholdOverride: ThresholdRule(maxAddedLines: 42, maxRemovedLines: 30, maxTotalDelta: 60)
                )
            ],
            globalThreshold: ThresholdRule(maxAddedLines: 200, maxRemovedLines: 200, maxTotalDelta: 300),
            notificationsEnabled: false,
            refreshInterval: .fiveMinutes,
            launchAtLogin: true
        )

        repository.save(settings)
        let loaded = repository.load()

        #expect(loaded == settings)
        defaults.removePersistentDomain(forName: suiteName)
    }
}
