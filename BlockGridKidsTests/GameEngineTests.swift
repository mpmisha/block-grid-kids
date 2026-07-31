import XCTest
@testable import BlockGridKids

final class GameEngineTests: XCTestCase {

    private func makeEngine(bestScore: Int = 0,
                            boardSize: Int = Board.defaultSize) -> (GameEngine, InMemoryHighScoreStore) {
        let store = InMemoryHighScoreStore(bestScore: bestScore, boardSize: boardSize)
        return (GameEngine(boardSize: boardSize, scoreStore: store), store)
    }

    func testNewGameStartsEmptyWithAFullTray() {
        let (engine, _) = makeEngine()
        XCTAssertEqual(engine.score, 0)
        XCTAssertFalse(engine.isGameOver)
        XCTAssertTrue(engine.board.isCompletelyEmpty)
        XCTAssertEqual(engine.tray.count, GameConfiguration.traySize)
        XCTAssertEqual(engine.remainingPieces.count, GameConfiguration.traySize)
    }

    func testTrayAlwaysContainsAPlayablePieceOnAnEmptyBoard() {
        for _ in 0..<25 {
            let (engine, _) = makeEngine()
            XCTAssertTrue(engine.hasAvailableMove())
        }
    }

    func testPlacingScoresOnePointPerCell() {
        let (engine, _) = makeEngine()
        guard let piece = engine.piece(at: 0),
              let origin = engine.board.firstValidOrigin(for: piece.shape) else {
            return XCTFail("Expected a placeable piece")
        }

        let result = engine.place(pieceAt: 0, origin: origin)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.breakdown.placementPoints, piece.cellCount)
        XCTAssertEqual(engine.score, piece.cellCount)
        XCTAssertNil(engine.piece(at: 0))
    }

    func testIllegalPlacementIsRejected() {
        let (engine, _) = makeEngine()
        let result = engine.place(pieceAt: 0, origin: GridPosition(row: 99, col: 99))
        XCTAssertNil(result)
        XCTAssertEqual(engine.score, 0)
        XCTAssertNotNil(engine.piece(at: 0))
    }

    func testTrayRefillsOnlyAfterEveryPieceIsUsed() {
        let (engine, _) = makeEngine()
        var refillCount = 0

        for index in 0..<GameConfiguration.traySize {
            guard let piece = engine.piece(at: index),
                  let origin = engine.board.firstValidOrigin(for: piece.shape) else { continue }
            if let result = engine.place(pieceAt: index, origin: origin), result.didRefillTray {
                refillCount += 1
            }
        }

        XCTAssertEqual(refillCount, 1)
        XCTAssertEqual(engine.remainingPieces.count, GameConfiguration.traySize)
    }

    func testBestScoreIsPersistedToTheStore() {
        let (engine, store) = makeEngine()
        guard let piece = engine.piece(at: 0),
              let origin = engine.board.firstValidOrigin(for: piece.shape) else {
            return XCTFail("Expected a placeable piece")
        }

        engine.place(pieceAt: 0, origin: origin)
        XCTAssertEqual(store.bestScore(forBoardSize: engine.boardSize), engine.score)
        XCTAssertEqual(engine.bestScore, engine.score)
    }

    /// The HUD target must not move while a run is in progress, otherwise the
    /// player can never see how far past their old best they got.
    func testVisibleBestScoreStaysFrozenUntilTheGameEnds() {
        let (engine, _) = makeEngine(bestScore: 3)
        XCTAssertEqual(engine.visibleBestScore, 3)

        guard let piece = engine.piece(at: 0),
              let origin = engine.board.firstValidOrigin(for: piece.shape) else {
            return XCTFail("Expected a placeable piece")
        }
        let result = engine.place(pieceAt: 0, origin: origin)

        XCTAssertGreaterThan(engine.score, 0)
        XCTAssertEqual(engine.bestScore, max(3, engine.score))
        XCTAssertEqual(engine.visibleBestScore, 3, "The displayed best must not move mid-game")
        XCTAssertEqual(result?.isNewBestScore, false, "A new best is only announced at game over")
    }

    func testExistingBestScoreIsLoadedAndNotBeatenTooEarly() {
        let (engine, _) = makeEngine(bestScore: 10_000)
        XCTAssertEqual(engine.bestScore, 10_000)

        guard let piece = engine.piece(at: 0),
              let origin = engine.board.firstValidOrigin(for: piece.shape) else {
            return XCTFail("Expected a placeable piece")
        }
        let result = engine.place(pieceAt: 0, origin: origin)
        XCTAssertEqual(result?.isNewBestScore, false)
        XCTAssertEqual(engine.bestScore, 10_000)
    }

    func testResetBestScoreClearsTheStore() {
        let (engine, store) = makeEngine(bestScore: 4_242)
        engine.resetBestScore()
        XCTAssertEqual(engine.bestScore, 0)
        XCTAssertEqual(engine.visibleBestScore, 0)
        XCTAssertEqual(store.bestScore(forBoardSize: engine.boardSize), 0)
    }

    func testChangingBoardSizeStartsAFreshGameAndSwapsTheBestScore() {
        let (engine, store) = makeEngine(bestScore: 500)
        store.setBestScore(120, forBoardSize: 5)

        if let piece = engine.piece(at: 0),
           let origin = engine.board.firstValidOrigin(for: piece.shape) {
            engine.place(pieceAt: 0, origin: origin)
        }

        XCTAssertTrue(engine.changeBoardSize(to: 5))
        XCTAssertEqual(engine.boardSize, 5)
        XCTAssertEqual(engine.board.size, 5)
        XCTAssertEqual(engine.score, 0)
        XCTAssertTrue(engine.board.isCompletelyEmpty)
        XCTAssertEqual(engine.bestScore, 120, "Each board size keeps its own best score")
        XCTAssertEqual(engine.remainingPieces.count, GameConfiguration.traySize)

        XCTAssertFalse(engine.changeBoardSize(to: 5), "Re-selecting the current size is a no-op")
    }

    func testSnapshotFromAnotherBoardSizeIsRejected() {
        let (small, _) = makeEngine(boardSize: 5)
        let snapshot = small.makeSnapshot()

        let (large, _) = makeEngine()
        XCTAssertFalse(large.restore(from: snapshot))
        XCTAssertEqual(large.board.size, Board.defaultSize)
    }

    func testStartNewGameClearsEverythingButTheBestScore() {
        let (engine, _) = makeEngine()
        if let piece = engine.piece(at: 0),
           let origin = engine.board.firstValidOrigin(for: piece.shape) {
            engine.place(pieceAt: 0, origin: origin)
        }
        let best = engine.bestScore

        engine.startNewGame()
        XCTAssertEqual(engine.score, 0)
        XCTAssertTrue(engine.board.isCompletelyEmpty)
        XCTAssertFalse(engine.isGameOver)
        XCTAssertEqual(engine.bestScore, best)
    }

    func testSnapshotRoundTripsThroughJSON() throws {
        let (engine, _) = makeEngine()
        if let piece = engine.piece(at: 1),
           let origin = engine.board.firstValidOrigin(for: piece.shape) {
            engine.place(pieceAt: 1, origin: origin)
        }

        let snapshot = engine.makeSnapshot()
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(GameSnapshot.self, from: data)
        XCTAssertEqual(decoded, snapshot)

        let (restored, _) = makeEngine()
        XCTAssertTrue(restored.restore(from: decoded))
        XCTAssertEqual(restored.score, engine.score)
        XCTAssertEqual(restored.board, engine.board)
    }

    func testRestoreRejectsAFinishedOrEmptySnapshot() {
        let (engine, _) = makeEngine()

        let emptySnapshot = GameSnapshot(
            board: Board(),
            tray: Array(repeating: nil, count: GameConfiguration.traySize),
            score: 0,
            streak: 0,
            isGameOver: false
        )
        XCTAssertFalse(engine.restore(from: emptySnapshot))

        var playedBoard = Board()
        playedBoard.place(
            ShapeTemplate(id: "dot", cells: [(0, 0)], weight: 1),
            at: GridPosition(row: 0, col: 0),
            colorIndex: 0
        )
        let finishedSnapshot = GameSnapshot(
            board: playedBoard,
            tray: Array(repeating: nil, count: GameConfiguration.traySize),
            score: 30,
            streak: 0,
            isGameOver: true
        )
        XCTAssertFalse(engine.restore(from: finishedSnapshot))
    }

    func testGameEndsWhenNothingFits() {        let (engine, _) = makeEngine()
        var safetyLimit = 400

        while !engine.isGameOver && safetyLimit > 0 {
            safetyLimit -= 1
            var didPlace = false
            for index in 0..<GameConfiguration.traySize {
                guard let piece = engine.piece(at: index),
                      let origin = engine.board.firstValidOrigin(for: piece.shape) else { continue }
                engine.place(pieceAt: index, origin: origin)
                didPlace = true
                break
            }
            if !didPlace { break }
        }

        // A greedy top-left strategy always fills the board eventually.
        XCTAssertTrue(engine.isGameOver, "Expected the greedy run to reach a game over")
        XCTAssertFalse(engine.hasAvailableMove())
        XCTAssertGreaterThan(engine.score, 0)
    }

    // MARK: - Perfect clears

    /// Builds a 5x5 game one move away from an empty board: the top row is
    /// filled except for its first cell, and the tray holds a single 1x1.
    private func makeEngineOneMoveFromAPerfectClear() -> GameEngine {
        let (engine, _) = makeEngine(boardSize: 5)
        var board = Board(size: 5)
        for col in 1..<5 {
            board[GridPosition(row: 0, col: col)] = 0
        }
        let single = Piece(
            shape: ShapeTemplate(id: "test-single", cells: [(0, 0)], weight: 1),
            colorIndex: 1
        )
        let snapshot = GameSnapshot(
            board: board,
            tray: [single, nil, nil],
            score: 12,
            streak: 0,
            isGameOver: false
        )
        XCTAssertTrue(engine.restore(from: snapshot))
        return engine
    }

    func testEmptyingTheBoardIsReportedAsAPerfectClear() {
        let engine = makeEngineOneMoveFromAPerfectClear()
        XCTAssertEqual(engine.level, 1)
        let skinBefore = engine.skin

        let result = engine.place(pieceAt: 0, origin: GridPosition(row: 0, col: 0))

        XCTAssertEqual(result?.clearedRows, [0])
        XCTAssertTrue(result?.isPerfectClear == true)
        XCTAssertTrue(engine.board.isCompletelyEmpty)
        XCTAssertEqual(engine.perfectClears, 1)
        XCTAssertEqual(engine.level, 2)
        XCTAssertEqual(result?.level, 2)
        XCTAssertNotEqual(engine.skin, skinBefore, "A perfect clear must change the look")
        XCTAssertGreaterThanOrEqual(engine.skin.differenceCount(from: skinBefore), 2)
    }

    func testClearingALineWithoutEmptyingTheBoardIsNotAPerfectClear() {
        let (engine, _) = makeEngine(boardSize: 5)
        var board = Board(size: 5)
        for col in 1..<5 {
            board[GridPosition(row: 0, col: col)] = 0
        }
        // One stray block survives the clear, so the board is not swept clean.
        board[GridPosition(row: 3, col: 3)] = 2

        let single = Piece(
            shape: ShapeTemplate(id: "test-single", cells: [(0, 0)], weight: 1),
            colorIndex: 1
        )
        XCTAssertTrue(engine.restore(from: GameSnapshot(
            board: board,
            tray: [single, nil, nil],
            score: 12,
            streak: 0,
            isGameOver: false
        )))

        let result = engine.place(pieceAt: 0, origin: GridPosition(row: 0, col: 0))
        XCTAssertTrue(result?.didClearLines == true)
        XCTAssertFalse(result?.isPerfectClear == true)
        XCTAssertEqual(engine.perfectClears, 0)
        XCTAssertEqual(engine.level, 1)
        XCTAssertEqual(engine.skin, .initial)
    }

    func testPlacingWithoutClearingNeverCountsAsAPerfectClear() {
        let (engine, _) = makeEngine()
        guard let piece = engine.piece(at: 0),
              let origin = engine.board.firstValidOrigin(for: piece.shape) else {
            return XCTFail("Expected a placeable piece")
        }
        // The board starts empty, so this guards the "empty board" check from
        // firing on a placement that cleared nothing.
        let result = engine.place(pieceAt: 0, origin: origin)
        XCTAssertFalse(result?.isPerfectClear == true)
        XCTAssertEqual(engine.perfectClears, 0)
    }

    func testLevelAndSkinSurviveASnapshotRoundTrip() throws {
        let engine = makeEngineOneMoveFromAPerfectClear()
        engine.place(pieceAt: 0, origin: GridPosition(row: 0, col: 0))
        let earnedSkin = engine.skin

        let data = try JSONEncoder().encode(engine.makeSnapshot())
        let restored = try JSONDecoder().decode(GameSnapshot.self, from: data)

        let (fresh, _) = makeEngine(boardSize: 5)
        XCTAssertTrue(fresh.restore(from: restored))
        XCTAssertEqual(fresh.skin, earnedSkin)
        XCTAssertEqual(fresh.perfectClears, 1)
        XCTAssertEqual(fresh.level, 2)
    }

    func testOldSavesWithoutASkinRestoreToTheStartingLook() {
        let (engine, _) = makeEngine(boardSize: 5)
        var board = Board(size: 5)
        board[GridPosition(row: 2, col: 2)] = 3

        let single = Piece(
            shape: ShapeTemplate(id: "test-single", cells: [(0, 0)], weight: 1),
            colorIndex: 1
        )
        XCTAssertTrue(engine.restore(from: GameSnapshot(
            board: board,
            tray: [single, nil, nil],
            score: 5,
            streak: 0,
            isGameOver: false
        )))
        XCTAssertEqual(engine.skin, .initial)
        XCTAssertEqual(engine.level, 1)
    }

    func testStartingANewGameReturnsToTheStartingLook() {
        let engine = makeEngineOneMoveFromAPerfectClear()
        engine.place(pieceAt: 0, origin: GridPosition(row: 0, col: 0))
        XCTAssertNotEqual(engine.skin, .initial)

        engine.startNewGame()
        XCTAssertEqual(engine.skin, .initial)
        XCTAssertEqual(engine.perfectClears, 0)
        XCTAssertEqual(engine.level, 1)
    }
}
