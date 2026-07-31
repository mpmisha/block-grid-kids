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
    /// The best score as it was when this run started. Persisted so the frozen
    /// HUD value survives the app being closed mid-game.
    var baselineBestScore: Int?
}

/// Owns the board, the tray, the score and the game-over rule.
final class GameEngine {

    private(set) var board: Board
    private(set) var tray: [Piece?] = []
    private(set) var score = 0
    private(set) var streak = 0
    private(set) var isGameOver = false

    /// The all-time best actually stored on the device.
    private(set) var bestScore = 0
    /// The best score as it stood when the current run began. The HUD shows
    /// this for the whole run so the player can watch themselves close in on
    /// the target instead of the target moving with them.
    private(set) var baselineBestScore = 0

    /// The number to display. It only catches up with `bestScore` once the run
    /// is over.
    var visibleBestScore: Int { isGameOver ? bestScore : baselineBestScore }

    private var generator: ShapeGenerator
    private let scoreStore: HighScoreStoring

    init(boardSize: Int = Board.defaultSize,
         scoreStore: HighScoreStoring = HighScoreStore(),
         generator: ShapeGenerator = ShapeGenerator()) {
        self.scoreStore = scoreStore
        self.generator = generator
        self.board = Board(size: boardSize)
        self.bestScore = scoreStore.bestScore(forBoardSize: self.board.size)
        self.baselineBestScore = self.bestScore
        startNewGame()
    }

    /// Side length of the current board. Each size keeps its own best score,
    /// because a 5x5 run is not comparable to an 8x8 one.
    var boardSize: Int { board.size }

    /// Switches to a different board size and starts a fresh game on it.
    /// Does nothing when the requested size is already in play.
    @discardableResult
    func changeBoardSize(to newSize: Int) -> Bool {
        guard Board.availableSizes.contains(newSize), newSize != board.size else { return false }
        board = Board(size: newSize)
        bestScore = scoreStore.bestScore(forBoardSize: newSize)
        startNewGame()
        return true
    }

    // MARK: - Lifecycle

    func startNewGame() {
        board.removeAll()
        score = 0
        streak = 0
        isGameOver = false
        baselineBestScore = bestScore
        refillTray()
    }

    private func refillTray() {
        tray = generator.makeTray(for: board)
    }

    /// Positions that would be cleared by dropping the tray piece at `index`
    /// on `origin`. Empty when the move is illegal or clears nothing.
    func linesCompleted(byPieceAt index: Int, origin: GridPosition) -> (rows: [Int], columns: [Int]) {
        guard let piece = piece(at: index) else { return ([], []) }
        return board.linesCompletedIfPlaced(piece.shape, at: origin)
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

        // The stored best is kept up to date so an interrupted run is never
        // lost, but it is only *revealed* when the run ends.
        if score > bestScore {
            bestScore = score
            scoreStore.setBestScore(score, forBoardSize: board.size)
        }

        if !hasAvailableMove() {
            isGameOver = true
        }
        result.isGameOver = isGameOver
        result.isNewBestScore = isGameOver && score > baselineBestScore

        return result
    }

    // MARK: - High score

    func resetBestScore() {
        bestScore = 0
        baselineBestScore = 0
        scoreStore.setBestScore(0, forBoardSize: board.size)
    }

    // MARK: - Persistence

    func makeSnapshot() -> GameSnapshot {
        GameSnapshot(
            board: board,
            tray: tray,
            score: score,
            streak: streak,
            isGameOver: isGameOver,
            baselineBestScore: baselineBestScore
        )
    }

    /// Restores a saved game. Ignores snapshots that are finished or empty so a
    /// stale save never drops the player straight into a game-over screen.
    @discardableResult
    func restore(from snapshot: GameSnapshot) -> Bool {
        guard !snapshot.isGameOver else { return false }
        guard snapshot.board.size == board.size else { return false }
        guard snapshot.tray.count == GameConfiguration.traySize else { return false }
        guard snapshot.board.filledCellCount > 0 || snapshot.score > 0 else { return false }

        board = snapshot.board
        tray = snapshot.tray
        score = max(0, snapshot.score)
        streak = max(0, snapshot.streak)
        isGameOver = false
        // Keep the frozen target from the interrupted run, clamped so a stale
        // save can never show a target above the real stored best.
        baselineBestScore = min(bestScore, max(0, snapshot.baselineBestScore ?? bestScore))

        if remainingPieces.isEmpty {
            refillTray()
        }
        if !hasAvailableMove() {
            isGameOver = true
        }
        return !isGameOver
    }
}
