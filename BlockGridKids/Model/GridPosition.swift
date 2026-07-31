import Foundation

/// A coordinate on the game board. `row` grows downward, `col` grows rightward.
struct GridPosition: Hashable, Codable {
    var row: Int
    var col: Int

    init(row: Int, col: Int) {
        self.row = row
        self.col = col
    }

    func offset(byRow rowDelta: Int, col colDelta: Int) -> GridPosition {
        GridPosition(row: row + rowDelta, col: col + colDelta)
    }
}
