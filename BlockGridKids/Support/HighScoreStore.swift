import Foundation

/// Abstraction so the engine can be tested without touching `UserDefaults`.
/// Each board size keeps its own best score.
protocol HighScoreStoring: AnyObject {
    func bestScore(forBoardSize size: Int) -> Int
    func setBestScore(_ score: Int, forBoardSize size: Int)
}

/// Persists the all-time best score on the device, one per board size.
final class HighScoreStore: HighScoreStoring {

    private enum Key {
        /// Written by builds that predate the board-size setting.
        static let legacyBestScore = "bestScore"
        static func bestScore(_ size: Int) -> String { "bestScore.\(size)" }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        migrateLegacyScoreIfNeeded()
    }

    /// Moves a pre-existing single best score onto the 8x8 key so nobody loses
    /// a high score when updating to a build that has the size option.
    private func migrateLegacyScoreIfNeeded() {
        guard let legacy = defaults.object(forKey: Key.legacyBestScore) as? Int else { return }
        let key = Key.bestScore(Board.defaultSize)
        if defaults.object(forKey: key) == nil {
            defaults.set(max(0, legacy), forKey: key)
        }
        defaults.removeObject(forKey: Key.legacyBestScore)
    }

    func bestScore(forBoardSize size: Int) -> Int {
        defaults.integer(forKey: Key.bestScore(size))
    }

    func setBestScore(_ score: Int, forBoardSize size: Int) {
        defaults.set(max(0, score), forKey: Key.bestScore(size))
    }
}

/// An in-memory store, used by tests.
final class InMemoryHighScoreStore: HighScoreStoring {

    private var scores: [Int: Int] = [:]

    init(bestScore: Int = 0, boardSize: Int = Board.defaultSize) {
        scores[boardSize] = bestScore
    }

    func bestScore(forBoardSize size: Int) -> Int {
        scores[size] ?? 0
    }

    func setBestScore(_ score: Int, forBoardSize size: Int) {
        scores[size] = max(0, score)
    }
}
