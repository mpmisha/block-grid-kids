import Foundation

/// Everything that happened as a result of one successful placement.
struct PlacementResult: Equatable {
    var placedPositions: [GridPosition] = []
    var clearedRows: [Int] = []
    var clearedColumns: [Int] = []
    var clearedPositions: [GridPosition] = []
    var breakdown = ScoreBreakdown()
    var streak: Int = 0
    var totalScore: Int = 0
    var didRefillTray = false
    var isNewBestScore = false
    var isGameOver = false

    var clearedLineCount: Int { clearedRows.count + clearedColumns.count }
    var didClearLines: Bool { clearedLineCount > 0 }
}

/// Serializable game state, used to resume an interrupted game.
struct GameSnapshot: Codable, Equatable {
    var board: Board
    var tray: [Piece?]
    var score: Int
    var streak: Int
    var isGameOver: Bool
}

/// Owns the board, the tray, the score and the game-over rule.
final class GameEngine {

    private(set) var board = Board()
    private(set) var tray: [Piece?] = []
    private(set) var score = 0
    private(set) var streak = 0
    private(set) var isGameOver = false
    private(set) var bestScore = 0

    private var generator: ShapeGenerator
    private let scoreStore: HighScoreStoring

    init(scoreStore: HighScoreStoring = HighScoreStore(),
         generator: ShapeGenerator = ShapeGenerator()) {
        self.scoreStore = scoreStore
        self.generator = generator
        self.bestScore = scoreStore.bestScore
        startNewGame()
    }

    // MARK: - Lifecycle

    func startNewGame() {
        board.removeAll()
        score = 0
        streak = 0
        isGameOver = false
        refillTray()
    }

    private func refillTray() {
        tray = generator.makeTray(for: board)
    }

    // MARK: - Queries

    var remainingPieces: [Piece] {
        tray.compactMap { $0 }
    }

    func piece(at index: Int) -> Piece? {
        guard tray.indices.contains(index) else { return nil }
        return tray[index]
    }

    func canPlace(pieceAt index: Int, origin: GridPosition) -> Bool {
        guard let piece = piece(at: index) else { return false }
        return board.canPlace(piece.shape, at: origin)
    }

    /// True when at least one tray piece still fits somewhere.
    func hasAvailableMove() -> Bool {
        remainingPieces.contains { board.canPlaceAnywhere($0.shape) }
    }

    // MARK: - Playing

    /// Attempts to place the tray piece at `index` with its top-left cell at
    /// `origin`. Returns `nil` when the move is illegal.
    @discardableResult
    func place(pieceAt index: Int, origin: GridPosition) -> PlacementResult? {
        guard !isGameOver,
              let piece = piece(at: index),
              board.canPlace(piece.shape, at: origin) else { return nil }

        var result = PlacementResult()
        result.placedPositions = board.place(piece.shape, at: origin, colorIndex: piece.colorIndex)
        tray[index] = nil

        let completed = board.completedLines()
        result.clearedRows = completed.rows
        result.clearedColumns = completed.columns

        if result.didClearLines {
            streak += 1
            result.clearedPositions = board.clear(rows: completed.rows, columns: completed.columns)
        } else {
            streak = 0
        }
        result.streak = streak

        result.breakdown = ScoringEngine.breakdown(
            cellCount: piece.cellCount,
            lineCount: result.clearedLineCount,
            streak: streak
        )
        score += result.breakdown.total
        result.totalScore = score

        if remainingPieces.isEmpty {
            refillTray()
            result.didRefillTray = true
        }

        if score > bestScore {
            bestScore = score
            scoreStore.bestScore = score
            result.isNewBestScore = true
        }

        if !hasAvailableMove() {
            isGameOver = true
        }
        result.isGameOver = isGameOver

        return result
    }

    // MARK: - High score

    func resetBestScore() {
        bestScore = 0
        scoreStore.bestScore = 0
    }

    // MARK: - Persistence

    func makeSnapshot() -> GameSnapshot {
        GameSnapshot(board: board, tray: tray, score: score, streak: streak, isGameOver: isGameOver)
    }

    /// Restores a saved game. Ignores snapshots that are finished or empty so a
    /// stale save never drops the player straight into a game-over screen.
    @discardableResult
    func restore(from snapshot: GameSnapshot) -> Bool {
        guard !snapshot.isGameOver else { return false }
        guard snapshot.tray.count == GameConfiguration.traySize else { return false }
        guard snapshot.board.filledCellCount > 0 || snapshot.score > 0 else { return false }

        board = snapshot.board
        tray = snapshot.tray
        score = max(0, snapshot.score)
        streak = max(0, snapshot.streak)
        isGameOver = false

        if remainingPieces.isEmpty {
            refillTray()
        }
        if !hasAvailableMove() {
            isGameOver = true
        }
        return !isGameOver
    }
}
