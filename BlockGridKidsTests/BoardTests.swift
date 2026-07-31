import XCTest
@testable import BlockGridKids

final class BoardTests: XCTestCase {

    func testNewBoardIsEmpty() {
        let board = Board()
        XCTAssertTrue(board.isCompletelyEmpty)
        XCTAssertEqual(board.filledCellCount, 0)
    }

    func testCanPlaceInsideBounds() {
        let board = Board()
        let square = ShapeTemplate(id: "s", cells: [(0, 0), (0, 1), (1, 0), (1, 1)], weight: 1)
        XCTAssertTrue(board.canPlace(square, at: GridPosition(row: 0, col: 0)))
        XCTAssertTrue(board.canPlace(square, at: GridPosition(row: 6, col: 6)))
    }

    func testCannotPlaceOutsideBounds() {
        let board = Board()
        let square = ShapeTemplate(id: "s", cells: [(0, 0), (0, 1), (1, 0), (1, 1)], weight: 1)
        XCTAssertFalse(board.canPlace(square, at: GridPosition(row: 7, col: 7)))
        XCTAssertFalse(board.canPlace(square, at: GridPosition(row: -1, col: 0)))
        XCTAssertFalse(board.canPlace(square, at: GridPosition(row: 0, col: 7)))
    }

    func testCannotPlaceOnOccupiedCells() {
        var board = Board()
        let dot = ShapeTemplate(id: "dot", cells: [(0, 0)], weight: 1)
        board.place(dot, at: GridPosition(row: 3, col: 3), colorIndex: 0)

        XCTAssertFalse(board.canPlace(dot, at: GridPosition(row: 3, col: 3)))
        XCTAssertTrue(board.canPlace(dot, at: GridPosition(row: 3, col: 4)))
    }

    func testPlaceFillsExpectedCells() {
        var board = Board()
        let bar = ShapeTemplate(id: "bar", cells: [(0, 0), (0, 1), (0, 2)], weight: 1)
        let filled = board.place(bar, at: GridPosition(row: 2, col: 1), colorIndex: 5)

        XCTAssertEqual(filled.count, 3)
        XCTAssertEqual(board[GridPosition(row: 2, col: 1)], 5)
        XCTAssertEqual(board[GridPosition(row: 2, col: 2)], 5)
        XCTAssertEqual(board[GridPosition(row: 2, col: 3)], 5)
        XCTAssertNil(board[GridPosition(row: 2, col: 4)])
        XCTAssertEqual(board.filledCellCount, 3)
    }

    func testCompletedRowIsDetectedAndCleared() {
        var board = Board()
        let dot = ShapeTemplate(id: "dot", cells: [(0, 0)], weight: 1)
        for col in 0..<board.size {
            board.place(dot, at: GridPosition(row: 4, col: col), colorIndex: 1)
        }

        let completed = board.completedLines()
        XCTAssertEqual(completed.rows, [4])
        XCTAssertTrue(completed.columns.isEmpty)

        let cleared = board.clear(rows: completed.rows, columns: completed.columns)
        XCTAssertEqual(cleared.count, board.size)
        XCTAssertTrue(board.isCompletelyEmpty)
    }

    func testCompletedColumnIsDetectedAndCleared() {
        var board = Board()
        let dot = ShapeTemplate(id: "dot", cells: [(0, 0)], weight: 1)
        for row in 0..<board.size {
            board.place(dot, at: GridPosition(row: row, col: 2), colorIndex: 3)
        }

        let completed = board.completedLines()
        XCTAssertEqual(completed.columns, [2])
        board.clear(rows: completed.rows, columns: completed.columns)
        XCTAssertTrue(board.isCompletelyEmpty)
    }

    func testIntersectingClearsCountEachCellOnce() {
        var board = Board()
        let dot = ShapeTemplate(id: "dot", cells: [(0, 0)], weight: 1)
        for col in 0..<board.size {
            board.place(dot, at: GridPosition(row: 0, col: col), colorIndex: 1)
        }
        for row in 1..<board.size {
            board.place(dot, at: GridPosition(row: row, col: 0), colorIndex: 1)
        }

        let completed = board.completedLines()
        XCTAssertEqual(completed.rows, [0])
        XCTAssertEqual(completed.columns, [0])

        let cleared = board.clear(rows: completed.rows, columns: completed.columns)
        // 8 in the row + 8 in the column - 1 shared corner.
        XCTAssertEqual(cleared.count, 15)
        XCTAssertTrue(board.isCompletelyEmpty)
    }

    func testCanPlaceAnywhereOnFullBoardIsFalse() {
        var board = Board()
        let dot = ShapeTemplate(id: "dot", cells: [(0, 0)], weight: 1)
        for row in 0..<board.size {
            for col in 0..<board.size {
                board.place(dot, at: GridPosition(row: row, col: col), colorIndex: 0)
            }
        }
        XCTAssertFalse(board.canPlaceAnywhere(dot))
        XCTAssertEqual(board.filledCellCount, 64)
    }

    func testShapeTemplateNormalizesOffsets() {
        let shape = ShapeTemplate(id: "shifted", cells: [(3, 5), (3, 6), (4, 5)], weight: 1)
        XCTAssertEqual(shape.width, 2)
        XCTAssertEqual(shape.height, 2)
        XCTAssertTrue(shape.offsets.contains(GridPosition(row: 0, col: 0)))
        XCTAssertEqual(shape.offsets.map(\.row).min(), 0)
        XCTAssertEqual(shape.offsets.map(\.col).min(), 0)
    }

    func testEveryLibraryShapeFitsOnAnEmptyBoard() {
        let board = Board()
        for shape in ShapeLibrary.all {
            XCTAssertTrue(board.canPlaceAnywhere(shape), "\(shape.id) does not fit an empty board")
            XCTAssertLessThanOrEqual(shape.width, Board.defaultSize)
            XCTAssertLessThanOrEqual(shape.height, Board.defaultSize)
        }
    }

    func testShapeLibraryHasUniqueIdentifiers() {
        let ids = ShapeLibrary.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    // MARK: - Clear prediction

    func testLinesCompletedIfPlacedPredictsARowWithoutMutating() {
        var board = Board()
        // Fill the whole top row except the last cell.
        for col in 0..<(board.size - 1) {
            board[GridPosition(row: 0, col: col)] = 1
        }
        let dot = try! XCTUnwrap(ShapeLibrary.shape(withID: "dot"))
        let gap = GridPosition(row: 0, col: board.size - 1)

        let before = board
        let lines = board.linesCompletedIfPlaced(dot, at: gap)

        XCTAssertEqual(lines.rows, [0])
        XCTAssertTrue(lines.columns.isEmpty)
        XCTAssertEqual(board, before, "Prediction must not change the board")
        XCTAssertTrue(board.completedLines().rows.isEmpty)
    }

    func testLinesCompletedIfPlacedPredictsARowAndColumnTogether() {
        var board = Board()
        let corner = GridPosition(row: 0, col: 0)
        for col in 1..<board.size { board[GridPosition(row: 0, col: col)] = 2 }
        for row in 1..<board.size { board[GridPosition(row: row, col: 0)] = 2 }

        let dot = try! XCTUnwrap(ShapeLibrary.shape(withID: "dot"))
        let lines = board.linesCompletedIfPlaced(dot, at: corner)

        XCTAssertEqual(lines.rows, [0])
        XCTAssertEqual(lines.columns, [0])
    }

    func testLinesCompletedIfPlacedIsEmptyForAnIllegalOrAharmlessMove() {
        var board = Board()
        let dot = try! XCTUnwrap(ShapeLibrary.shape(withID: "dot"))

        let harmless = board.linesCompletedIfPlaced(dot, at: GridPosition(row: 3, col: 3))
        XCTAssertTrue(harmless.rows.isEmpty)
        XCTAssertTrue(harmless.columns.isEmpty)

        board[GridPosition(row: 3, col: 3)] = 0
        let illegal = board.linesCompletedIfPlaced(dot, at: GridPosition(row: 3, col: 3))
        XCTAssertTrue(illegal.rows.isEmpty)
        XCTAssertTrue(illegal.columns.isEmpty)
    }

    // MARK: - Board size

    func testSmallBoardHasItsOwnGeometryAndClearsShorterLines() {
        var board = Board(size: 5)
        XCTAssertEqual(board.size, 5)
        XCTAssertEqual(board.cells.count, 25)
        XCTAssertFalse(board.isInBounds(GridPosition(row: 0, col: 5)))

        for col in 0..<5 { board[GridPosition(row: 2, col: col)] = 3 }
        XCTAssertEqual(board.completedLines().rows, [2])
        XCTAssertEqual(board.clear(rows: [2], columns: []).count, 5)
    }

    func testUnknownBoardSizeFallsBackToTheDefault() {
        XCTAssertEqual(Board(size: 7).size, Board.defaultSize)
        XCTAssertEqual(Board(size: 0).size, Board.defaultSize)
    }

    func testSmallBoardOnlyOffersShapesThatFitComfortably() {
        for shape in ShapeLibrary.shapes(forBoardSize: 5) {
            XCTAssertLessThanOrEqual(shape.width, 3)
            XCTAssertLessThanOrEqual(shape.height, 3)
            XCTAssertLessThanOrEqual(shape.cellCount, 4)
        }
        XCTAssertEqual(ShapeLibrary.shapes(forBoardSize: 8).count, ShapeLibrary.all.count)
    }

    func testBoardSurvivesAJSONRoundTripAtBothSizes() throws {
        for size in Board.availableSizes {
            var board = Board(size: size)
            board[GridPosition(row: 1, col: 1)] = 4
            let decoded = try JSONDecoder().decode(Board.self, from: JSONEncoder().encode(board))
            XCTAssertEqual(decoded, board)
            XCTAssertEqual(decoded.size, size)
        }
    }
}
