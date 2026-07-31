import Foundation

/// The two player-facing toggles. Deliberately tiny: this game has no other
/// configuration, no accounts and nothing to sync.
final class SettingsStore {

    static let shared = SettingsStore()

    private enum Key {
        static let sound = "soundEnabled"
        static let haptics = "hapticsEnabled"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Key.sound) == nil {
            defaults.set(true, forKey: Key.sound)
        }
        if defaults.object(forKey: Key.haptics) == nil {
            defaults.set(true, forKey: Key.haptics)
        }
    }

    var isSoundEnabled: Bool {
        get { defaults.bool(forKey: Key.sound) }
        set { defaults.set(newValue, forKey: Key.sound) }
    }

    var areHapticsEnabled: Bool {
        get { defaults.bool(forKey: Key.haptics) }
        set { defaults.set(newValue, forKey: Key.haptics) }
    }
}

/// Saves an in-progress game so closing the app never loses a kid's board.
final class GameStateStore {

    private enum Key {
        static let savedGame = "savedGame"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(_ snapshot: GameSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Key.savedGame)
    }

    func loadSnapshot() -> GameSnapshot? {
        guard let data = defaults.data(forKey: Key.savedGame) else { return nil }
        return try? JSONDecoder().decode(GameSnapshot.self, from: data)
    }

    func clear() {
        defaults.removeObject(forKey: Key.savedGame)
    }
}
