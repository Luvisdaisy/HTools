import Foundation

final class PreferencesStore {
    // The legacy domain is intentionally retained only as an upgrade migration key.
    static func migrateLegacyPreferences(defaults: UserDefaults = .standard,
                                          legacy: [String: Any]? = UserDefaults.standard.persistentDomain(forName: "local.finder-fixer")) {
        guard !defaults.bool(forKey: "legacyPreferencesMigrated.v1") else { return }
        if defaults.data(forKey: "windowPreferences.v1") == nil,
           let data = legacy?["windowPreferences.v1"] as? Data,
           let preferences = try? JSONDecoder().decode(Preferences.self, from: data), preferences.fixedSize.isValid {
            defaults.set(data, forKey: "windowPreferences.v1")
        }
        defaults.set(true, forKey: "legacyPreferencesMigrated.v1")
    }

    private let defaults: UserDefaults
    private let key = "windowPreferences.v1"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> Preferences {
        guard let data = defaults.data(forKey: key),
              var result = try? JSONDecoder().decode(Preferences.self, from: data) else { return Preferences() }
        if !result.fixedSize.isValid { result.fixedSize = .initial }
        return result
    }

    func save(_ preferences: Preferences) {
        guard preferences.fixedSize.isValid,
              let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: key)
    }
}
