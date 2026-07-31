import Foundation

/// Tunable game constants shared by the logic and rendering layers.
enum GameConfiguration {
    /// Number of distinct block colors in the palette.
    static let colorCount = 8
    /// How many pieces sit in the tray at once.
    static let traySize = 3
    /// How many times the generator will re-roll a set that cannot be played.
    static let maxTraySetAttempts = 40
}

/// Produces the tray sets. Random, but biased so a young player rarely gets an
/// instantly unplayable hand.
struct ShapeGenerator {

    private var randomNumberGenerator: RandomNumberGenerator

    init(randomNumberGenerator: RandomNumberGenerator = SystemRandomNumberGenerator()) {
        self.randomNumberGenerator = randomNumberGenerator
    }

    /// Builds a full tray. Guarantees at least one piece is playable on `board`
    /// whenever any shape at all can still be placed.
    mutating func makeTray(for board: Board) -> [Piece] {
        for _ in 0..<GameConfiguration.maxTraySetAttempts {
            let candidate = (0..<GameConfiguration.traySize).map { _ in makePiece() }
            if candidate.contains(where: { board.canPlaceAnywhere($0.shape) }) {
                return candidate
            }
        }

        // Fall back to the smallest shapes so the board stays playable as long
        // as physically possible.
        if let rescue = ShapeLibrary.rescueShapes.first(where: { board.canPlaceAnywhere($0) }) {
            var pieces = [Piece(shape: rescue, colorIndex: randomColorIndex())]
            while pieces.count < GameConfiguration.traySize {
                pieces.append(makePiece())
            }
            return pieces
        }

        // The board genuinely has no room left; the engine will detect game over.
        return (0..<GameConfiguration.traySize).map { _ in makePiece() }
    }

    mutating func makePiece() -> Piece {
        Piece(shape: randomShape(), colorIndex: randomColorIndex())
    }

    // MARK: - Randomness

    private mutating func randomColorIndex() -> Int {
        Int.random(in: 0..<GameConfiguration.colorCount, using: &randomNumberGenerator)
    }

    private mutating func randomShape() -> ShapeTemplate {
        let shapes = ShapeLibrary.all
        let totalWeight = shapes.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return shapes[0] }

        var roll = Double.random(in: 0..<totalWeight, using: &randomNumberGenerator)
        for shape in shapes {
            roll -= shape.weight
            if roll <= 0 {
                return shape
            }
        }
        return shapes[shapes.count - 1]
    }
}
