import XCTest
@testable import BlockGridKids

final class GameEngineTests: XCTestCase {

    private func makeEngine(bestScore: Int = 0) -> (GameEngine, InMemoryHighScoreStore) {
        let store = InMemoryHighScoreStore(bestScore: bestScore)
        return (GameEngine(scoreStore: store), store)
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

        let result = engine.place(pieceAt: 0, origin: origin)
        XCTAssertEqual(result?.isNewBestScore, true)
        XCTAssertEqual(store.bestScore, engine.score)
        XCTAssertEqual(engine.bestScore, engine.score)
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
        XCTAssertEqual(store.bestScore, 0)
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

    func testGameEndsWhenNothingFits() {
        let (engine, _) = makeEngine()
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
}
