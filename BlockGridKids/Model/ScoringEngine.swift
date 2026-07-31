import Foundation

/// Points awarded for a single placement.
struct ScoreBreakdown: Equatable {
    var placementPoints: Int = 0
    var lineClearPoints: Int = 0
    var streakPoints: Int = 0

    var total: Int { placementPoints + lineClearPoints + streakPoints }
}

/// Pure scoring rules, kept separate so they are easy to tune and to test.
enum ScoringEngine {

    /// `+1` per cell placed.
    static func placementPoints(cellCount: Int) -> Int {
        max(0, cellCount)
    }

    /// `10 x lines^2`, so simultaneous clears are worth far more.
    static func lineClearPoints(lineCount: Int) -> Int {
        guard lineCount > 0 else { return 0 }
        return 10 * lineCount * lineCount
    }

    /// `5 x streak`, awarded only when the placement cleared something.
    /// `streak` is the streak value *after* this placement, where the first
    /// clearing placement in a run has a streak of `1` and earns no bonus.
    static func streakPoints(streak: Int, didClear: Bool) -> Int {
        guard didClear, streak > 1 else { return 0 }
        return 5 * (streak - 1)
    }

    static func breakdown(cellCount: Int, lineCount: Int, streak: Int) -> ScoreBreakdown {
        ScoreBreakdown(
            placementPoints: placementPoints(cellCount: cellCount),
            lineClearPoints: lineClearPoints(lineCount: lineCount),
            streakPoints: streakPoints(streak: streak, didClear: lineCount > 0)
        )
    }
}
