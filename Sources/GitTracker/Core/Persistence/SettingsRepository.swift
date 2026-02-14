import Foundation

protocol SettingsPersisting {
    func load() -> AppSettings
    func save(_ settings: AppSettings)
}

struct UserDefaultsSettingsRepository: SettingsPersisting {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "GitTracker.settings.v1") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> AppSettings {
        guard let data = defaults.data(forKey: key) else {
            return .default
        }
        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            return .default
        }
    }

    func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }
        defaults.set(data, forKey: key)
    }
}
