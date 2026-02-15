import Foundation
import Testing
@testable import GitTracker

struct AppSettingsCodingTests {
    @Test
    func decodesLegacySettingsWithoutLaunchAtLoginFlag() throws {
        struct LegacySettings: Codable {
            var projectSpecs: [ProjectSpec]
            var globalThreshold: ThresholdRule
            var notificationsEnabled: Bool
            var refreshInterval: RefreshInterval
        }

        let legacy = LegacySettings(
            projectSpecs: [ProjectSpec(input: .exact(path: "/tmp/project"))],
            globalThreshold: ThresholdRule(maxAddedLines: 100, maxRemovedLines: 90, maxTotalDelta: 140),
            notificationsEnabled: false,
            refreshInterval: .oneMinute
        )

        let data = try JSONEncoder().encode(legacy)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        #expect(decoded.projectSpecs == legacy.projectSpecs)
        #expect(decoded.globalThreshold == legacy.globalThreshold)
        #expect(decoded.notificationsEnabled == legacy.notificationsEnabled)
        #expect(decoded.refreshInterval == legacy.refreshInterval)
        #expect(decoded.launchAtLogin == false)
    }
}
