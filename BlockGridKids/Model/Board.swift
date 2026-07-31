import Foundation

/// The square playfield. Each cell either is empty (`nil`) or holds a color index.
struct Board: Codable, Equatable {

    /// Board sizes the player can pick between in settings.
    static let availableSizes = [5, 8]
    /// The size used for a fresh install and for saves written before the
    /// board-size setting existed.
    static let defaultSize = 8

    /// Number of rows and columns. The board is always square.
    let size: Int

    /// Row-major storage of `size * size` cells.
    private(set) var cells: [Int?]

    init(size: Int = Board.defaultSize) {
        self.size = Board.availableSizes.contains(size) ? size : Board.defaultSize
        cells = Array(repeating: nil, count: self.size * self.size)
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case size
        case cells
    }

    /// Decoding tolerates a missing `size` so a game saved by an older build
    /// still restores as an 8x8 board instead of being thrown away.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedSize = try container.decodeIfPresent(Int.self, forKey: .size) ?? Board.defaultSize
        let decodedCells = try container.decode([Int?].self, forKey: .cells)
        guard Board.availableSizes.contains(decodedSize),
              decodedCells.count == decodedSize * decodedSize else {
            throw DecodingError.dataCorruptedError(
                forKey: .cells,
                in: container,
                debugDescription: "Cell count does not match the board size"
            )
        }
        size = decodedSize
        cells = decodedCells
    }

    // MARK: - Cell access

    func isInBounds(_ position: GridPosition) -> Bool {
        position.row >= 0 && position.row < size && position.col >= 0 && position.col < size
    }

    private func index(of position: GridPosition) -> Int {
        position.row * size + position.col
    }

    subscript(position: GridPosition) -> Int? {
        get {
            guard isInBounds(position) else { return nil }
            return cells[index(of: position)]
        }
        set {
            guard isInBounds(position) else { return }
            cells[index(of: position)] = newValue
        }
    }

    func isEmpty(at position: GridPosition) -> Bool {
        guard isInBounds(position) else { return false }
        return cells[index(of: position)] == nil
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
            guard isInBounds(position) else { return false }
            guard cells[index(of: position)] == nil else { return false }
        }
        return true
    }

    /// True when the shape fits anywhere at all on the current board.
    func canPlaceAnywhere(_ shape: ShapeTemplate) -> Bool {
        firstValidOrigin(for: shape) != nil
    }

    /// The topmost-leftmost origin where the shape fits, if any.
    func firstValidOrigin(for shape: ShapeTemplate) -> GridPosition? {
        let maxRow = size - shape.height
        let maxCol = size - shape.width
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
            cells[index(of: position)] = colorIndex
        }
        return filled
    }

    // MARK: - Clearing

    /// Rows and columns that are currently completely filled.
    func completedLines() -> (rows: [Int], columns: [Int]) {
        var rows: [Int] = []
        var columns: [Int] = []

        for row in 0..<size {
            let isFull = (0..<size).allSatisfy { cells[row * size + $0] != nil }
            if isFull { rows.append(row) }
        }
        for col in 0..<size {
            let isFull = (0..<size).allSatisfy { cells[$0 * size + col] != nil }
            if isFull { columns.append(col) }
        }
        return (rows, columns)
    }

    /// Rows and columns that *would* be completed by dropping `shape` at
    /// `origin`, without mutating anything. Drives the drag-time hint that
    /// shows the player which lines a move is about to clear.
    func linesCompletedIfPlaced(_ shape: ShapeTemplate, at origin: GridPosition) -> (rows: [Int], columns: [Int]) {
        guard canPlace(shape, at: origin) else { return ([], []) }
        let added = Set(positions(for: shape, at: origin))

        func isFilled(row: Int, col: Int) -> Bool {
            cells[row * size + col] != nil || added.contains(GridPosition(row: row, col: col))
        }

        var rows: [Int] = []
        var columns: [Int] = []
        for row in 0..<size where (0..<size).allSatisfy({ isFilled(row: row, col: $0) }) {
            rows.append(row)
        }
        for col in 0..<size where (0..<size).allSatisfy({ isFilled(row: $0, col: col) }) {
            columns.append(col)
        }
        return (rows, columns)
    }

    /// Empties the given rows and columns. Returns every cleared position,
    /// de-duplicated so intersections are only reported once.
    @discardableResult
    mutating func clear(rows: [Int], columns: [Int]) -> [GridPosition] {
        var cleared: Set<GridPosition> = []

        for row in rows {
            for col in 0..<size {
                cleared.insert(GridPosition(row: row, col: col))
            }
        }
        for col in columns {
            for row in 0..<size {
                cleared.insert(GridPosition(row: row, col: col))
            }
        }
        for position in cleared {
            cells[index(of: position)] = nil
        }
        return Array(cleared)
    }

    mutating func removeAll() {
        cells = Array(repeating: nil, count: size * size)
    }
}
