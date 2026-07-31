import Foundation

/// The 8x8 playfield. Each cell either is empty (`nil`) or holds a color index.
struct Board: Codable, Equatable {

    /// Number of rows and columns. The board is always square.
    static let size = 8

    /// Row-major storage of `size * size` cells.
    private(set) var cells: [Int?]

    init() {
        cells = Array(repeating: nil, count: Board.size * Board.size)
    }

    // MARK: - Cell access

    static func isInBounds(_ position: GridPosition) -> Bool {
        position.row >= 0 && position.row < size && position.col >= 0 && position.col < size
    }

    private static func index(of position: GridPosition) -> Int {
        position.row * size + position.col
    }

    subscript(position: GridPosition) -> Int? {
        get {
            guard Board.isInBounds(position) else { return nil }
            return cells[Board.index(of: position)]
        }
        set {
            guard Board.isInBounds(position) else { return }
            cells[Board.index(of: position)] = newValue
        }
    }

    func isEmpty(at position: GridPosition) -> Bool {
        guard Board.isInBounds(position) else { return false }
        return cells[Board.index(of: position)] == nil
    }

    var isCompletelyEmpty: Bool {
        cells.allSatisfy { $0 == nil }
    }

    var filledCellCount: Int {
        cells.reduce(into: 0) { total, cell in
            if cell != nil { total += 1 }
        }
    }

    // MARK: - Placement

    /// The board positions a piece would occupy if anchored at `origin`.
    /// `origin` maps to the shape's normalized `(row: 0, col: 0)` corner.
    func positions(for shape: ShapeTemplate, at origin: GridPosition) -> [GridPosition] {
        shape.offsets.map { origin.offset(byRow: $0.row, col: $0.col) }
    }

    /// True when every cell the piece would occupy is in bounds and empty.
    func canPlace(_ shape: ShapeTemplate, at origin: GridPosition) -> Bool {
        for position in positions(for: shape, at: origin) {
            guard Board.isInBounds(position) else { return false }
            guard cells[Board.index(of: position)] == nil else { return false }
        }
        return true
    }

    /// True when the shape fits anywhere at all on the current board.
    func canPlaceAnywhere(_ shape: ShapeTemplate) -> Bool {
        firstValidOrigin(for: shape) != nil
    }

    /// The topmost-leftmost origin where the shape fits, if any.
    func firstValidOrigin(for shape: ShapeTemplate) -> GridPosition? {
        let maxRow = Board.size - shape.height
        let maxCol = Board.size - shape.width
        guard maxRow >= 0, maxCol >= 0 else { return nil }
        for row in 0...maxRow {
            for col in 0...maxCol {
                let origin = GridPosition(row: row, col: col)
                if canPlace(shape, at: origin) {
                    return origin
                }
            }
        }
        return nil
    }

    /// Fills the piece's cells with `colorIndex`. Returns the filled positions.
    @discardableResult
    mutating func place(_ shape: ShapeTemplate, at origin: GridPosition, colorIndex: Int) -> [GridPosition] {
        let filled = positions(for: shape, at: origin)
        for position in filled {
            cells[Board.index(of: position)] = colorIndex
        }
        return filled
    }

    // MARK: - Clearing

    /// Rows and columns that are currently completely filled.
    func completedLines() -> (rows: [Int], columns: [Int]) {
        var rows: [Int] = []
        var columns: [Int] = []

        for row in 0..<Board.size {
            let isFull = (0..<Board.size).allSatisfy { cells[row * Board.size + $0] != nil }
            if isFull { rows.append(row) }
        }
        for col in 0..<Board.size {
            let isFull = (0..<Board.size).allSatisfy { cells[$0 * Board.size + col] != nil }
            if isFull { columns.append(col) }
        }
        return (rows, columns)
    }

    /// Empties the given rows and columns. Returns every cleared position,
    /// de-duplicated so intersections are only reported once.
    @discardableResult
    mutating func clear(rows: [Int], columns: [Int]) -> [GridPosition] {
        var cleared: Set<GridPosition> = []

        for row in rows {
            for col in 0..<Board.size {
                cleared.insert(GridPosition(row: row, col: col))
            }
        }
        for col in columns {
            for row in 0..<Board.size {
                cleared.insert(GridPosition(row: row, col: col))
            }
        }
        for position in cleared {
            cells[Board.index(of: position)] = nil
        }
        return Array(cleared)
    }

    mutating func removeAll() {
        cells = Array(repeating: nil, count: Board.size * Board.size)
    }
}
