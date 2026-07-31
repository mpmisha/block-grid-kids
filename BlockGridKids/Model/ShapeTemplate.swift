import Foundation

/// An immutable block shape definition, normalized so the smallest row and
/// column are both `0`.
struct ShapeTemplate: Codable, Equatable, Identifiable {

    let id: String
    /// Cell offsets relative to the shape's top-left corner.
    let offsets: [GridPosition]
    /// Relative likelihood of this shape appearing. Higher spawns more often.
    let weight: Double

    var cellCount: Int { offsets.count }
    var width: Int { (offsets.map(\.col).max() ?? 0) + 1 }
    var height: Int { (offsets.map(\.row).max() ?? 0) + 1 }

    init(id: String, offsets: [GridPosition], weight: Double) {
        self.id = id
        self.offsets = ShapeTemplate.normalize(offsets)
        self.weight = weight
    }

    /// Convenience initializer taking `(row, col)` tuples.
    init(id: String, cells: [(Int, Int)], weight: Double) {
        self.init(
            id: id,
            offsets: cells.map { GridPosition(row: $0.0, col: $0.1) },
            weight: weight
        )
    }

    private static func normalize(_ offsets: [GridPosition]) -> [GridPosition] {
        guard let minRow = offsets.map(\.row).min(),
              let minCol = offsets.map(\.col).min() else { return offsets }
        return offsets.map { GridPosition(row: $0.row - minRow, col: $0.col - minCol) }
    }
}

/// The catalogue of every shape that can appear in the tray.
///
/// Weights are tuned for a young player: single cells and short bars are
/// common, while the awkward 3x3 block and 5-long bars are deliberately rare.
enum ShapeLibrary {

    static let all: [ShapeTemplate] = {
        var shapes: [ShapeTemplate] = []

        // Dot
        shapes.append(ShapeTemplate(id: "dot", cells: [(0, 0)], weight: 5))

        // Horizontal and vertical bars
        shapes.append(ShapeTemplate(id: "bar-h2", cells: [(0, 0), (0, 1)], weight: 10))
        shapes.append(ShapeTemplate(id: "bar-v2", cells: [(0, 0), (1, 0)], weight: 10))
        shapes.append(ShapeTemplate(id: "bar-h3", cells: [(0, 0), (0, 1), (0, 2)], weight: 9))
        shapes.append(ShapeTemplate(id: "bar-v3", cells: [(0, 0), (1, 0), (2, 0)], weight: 9))
        shapes.append(ShapeTemplate(id: "bar-h4", cells: [(0, 0), (0, 1), (0, 2), (0, 3)], weight: 5))
        shapes.append(ShapeTemplate(id: "bar-v4", cells: [(0, 0), (1, 0), (2, 0), (3, 0)], weight: 5))
        shapes.append(ShapeTemplate(id: "bar-h5", cells: [(0, 0), (0, 1), (0, 2), (0, 3), (0, 4)], weight: 2))
        shapes.append(ShapeTemplate(id: "bar-v5", cells: [(0, 0), (1, 0), (2, 0), (3, 0), (4, 0)], weight: 2))

        // Squares and rectangles
        shapes.append(ShapeTemplate(id: "square2", cells: [(0, 0), (0, 1), (1, 0), (1, 1)], weight: 9))
        shapes.append(ShapeTemplate(
            id: "square3",
            cells: [(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2), (2, 0), (2, 1), (2, 2)],
            weight: 1.5
        ))
        shapes.append(ShapeTemplate(
            id: "rect23",
            cells: [(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2)],
            weight: 3
        ))
        shapes.append(ShapeTemplate(
            id: "rect32",
            cells: [(0, 0), (0, 1), (1, 0), (1, 1), (2, 0), (2, 1)],
            weight: 3
        ))

        // Small corners (3 cells), all four rotations
        shapes.append(ShapeTemplate(id: "corner-tl", cells: [(0, 0), (0, 1), (1, 0)], weight: 7))
        shapes.append(ShapeTemplate(id: "corner-tr", cells: [(0, 0), (0, 1), (1, 1)], weight: 7))
        shapes.append(ShapeTemplate(id: "corner-bl", cells: [(0, 0), (1, 0), (1, 1)], weight: 7))
        shapes.append(ShapeTemplate(id: "corner-br", cells: [(0, 1), (1, 0), (1, 1)], weight: 7))

        // Large corners (5 cells), all four rotations
        shapes.append(ShapeTemplate(
            id: "bigcorner-tl",
            cells: [(0, 0), (0, 1), (0, 2), (1, 0), (2, 0)],
            weight: 2.5
        ))
        shapes.append(ShapeTemplate(
            id: "bigcorner-tr",
            cells: [(0, 0), (0, 1), (0, 2), (1, 2), (2, 2)],
            weight: 2.5
        ))
        shapes.append(ShapeTemplate(
            id: "bigcorner-bl",
            cells: [(0, 0), (1, 0), (2, 0), (2, 1), (2, 2)],
            weight: 2.5
        ))
        shapes.append(ShapeTemplate(
            id: "bigcorner-br",
            cells: [(0, 2), (1, 2), (2, 0), (2, 1), (2, 2)],
            weight: 2.5
        ))

        // L / J tetrominoes
        shapes.append(ShapeTemplate(id: "l-1", cells: [(0, 0), (1, 0), (2, 0), (2, 1)], weight: 3))
        shapes.append(ShapeTemplate(id: "l-2", cells: [(0, 1), (1, 1), (2, 1), (2, 0)], weight: 3))
        shapes.append(ShapeTemplate(id: "l-3", cells: [(0, 0), (0, 1), (1, 0), (2, 0)], weight: 3))
        shapes.append(ShapeTemplate(id: "l-4", cells: [(0, 0), (0, 1), (1, 1), (2, 1)], weight: 3))

        // T tetrominoes
        shapes.append(ShapeTemplate(id: "t-up", cells: [(0, 1), (1, 0), (1, 1), (1, 2)], weight: 3))
        shapes.append(ShapeTemplate(id: "t-down", cells: [(0, 0), (0, 1), (0, 2), (1, 1)], weight: 3))
        shapes.append(ShapeTemplate(id: "t-left", cells: [(0, 1), (1, 0), (1, 1), (2, 1)], weight: 3))
        shapes.append(ShapeTemplate(id: "t-right", cells: [(0, 0), (1, 0), (1, 1), (2, 0)], weight: 3))

        // S / Z tetrominoes
        shapes.append(ShapeTemplate(id: "s-h", cells: [(0, 1), (0, 2), (1, 0), (1, 1)], weight: 2))
        shapes.append(ShapeTemplate(id: "z-h", cells: [(0, 0), (0, 1), (1, 1), (1, 2)], weight: 2))
        shapes.append(ShapeTemplate(id: "s-v", cells: [(0, 0), (1, 0), (1, 1), (2, 1)], weight: 2))
        shapes.append(ShapeTemplate(id: "z-v", cells: [(0, 1), (1, 0), (1, 1), (2, 0)], weight: 2))

        return shapes
    }()

    /// The shapes worth offering on a board of `size` cells per side.
    ///
    /// The small board fills up fast, so anything wider than three cells or
    /// covering more than four is dropped; otherwise a single unlucky 3x3
    /// would end the game almost immediately.
    static func shapes(forBoardSize size: Int) -> [ShapeTemplate] {
        guard size < Board.defaultSize else { return all }
        return all.filter { $0.width <= 3 && $0.height <= 3 && $0.cellCount <= 4 }
    }

    /// The gentlest shapes, used as a fallback when nothing else fits.
    static let rescueShapes: [ShapeTemplate] = all
        .filter { $0.cellCount <= 2 }
        .sorted { $0.cellCount < $1.cellCount }

    static func shape(withID id: String) -> ShapeTemplate? {
        all.first { $0.id == id }
    }
}
