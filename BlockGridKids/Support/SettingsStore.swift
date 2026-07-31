import Foundation

/// The handful of player-facing preferences. Deliberately tiny: this game has
/// no accounts and nothing to sync.
final class SettingsStore {

    static let shared = SettingsStore()

    private enum Key {
        static let sound = "soundEnabled"
        static let haptics = "hapticsEnabled"
        static let boardSize = "boardSize"
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

    /// Side length of the playfield. Falls back to the default whenever the
    /// stored value is missing or is not one of the offered sizes.
    var boardSize: Int {
        get {
            let stored = defaults.integer(forKey: Key.boardSize)
            return Board.availableSizes.contains(stored) ? stored : Board.defaultSize
        }
        set {
            guard Board.availableSizes.contains(newValue) else { return }
            defaults.set(newValue, forKey: Key.boardSize)
        }
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
