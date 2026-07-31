import Foundation

/// Abstraction so the engine can be tested without touching `UserDefaults`.
protocol HighScoreStoring: AnyObject {
    var bestScore: Int { get set }
}

/// Persists the all-time best score on the device.
final class HighScoreStore: HighScoreStoring {

    private enum Key {
        static let bestScore = "bestScore"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var bestScore: Int {
        get { defaults.integer(forKey: Key.bestScore) }
        set { defaults.set(max(0, newValue), forKey: Key.bestScore) }
    }
}

/// An in-memory store, used by tests.
final class InMemoryHighScoreStore: HighScoreStoring {
    var bestScore: Int
    init(bestScore: Int = 0) {
        self.bestScore = bestScore
    }
}
