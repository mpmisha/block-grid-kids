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
        for col in 0..<Board.size {
            board.place(dot, at: GridPosition(row: 4, col: col), colorIndex: 1)
        }

        let completed = board.completedLines()
        XCTAssertEqual(completed.rows, [4])
        XCTAssertTrue(completed.columns.isEmpty)

        let cleared = board.clear(rows: completed.rows, columns: completed.columns)
        XCTAssertEqual(cleared.count, Board.size)
        XCTAssertTrue(board.isCompletelyEmpty)
    }

    func testCompletedColumnIsDetectedAndCleared() {
        var board = Board()
        let dot = ShapeTemplate(id: "dot", cells: [(0, 0)], weight: 1)
        for row in 0..<Board.size {
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
        for col in 0..<Board.size {
            board.place(dot, at: GridPosition(row: 0, col: col), colorIndex: 1)
        }
        for row in 1..<Board.size {
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
        for row in 0..<Board.size {
            for col in 0..<Board.size {
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
            XCTAssertLessThanOrEqual(shape.width, Board.size)
            XCTAssertLessThanOrEqual(shape.height, Board.size)
        }
    }

    func testShapeLibraryHasUniqueIdentifiers() {
        let ids = ShapeLibrary.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }
}
