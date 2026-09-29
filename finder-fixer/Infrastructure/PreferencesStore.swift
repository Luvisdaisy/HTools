import Foundation

final class PreferencesStore {
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
