import Foundation

/// Process names you have marked "never kill", persisted in UserDefaults.
struct ProtectedNamesStore {
    private static let key = "protectedProcessNames"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> Set<String> {
        Set(defaults.stringArray(forKey: Self.key) ?? [])
    }

    func save(_ names: Set<String>) {
        defaults.set(names.sorted(), forKey: Self.key)
    }
}
