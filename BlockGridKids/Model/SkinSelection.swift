import Foundation

/// Which visual variant the game is currently wearing.
///
/// Four independent axes, four options each, giving 256 permutations. The type
/// is deliberately free of any UIKit types so it can live in the model layer,
/// be persisted inside `GameSnapshot` and be unit tested. `SkinCatalog` maps
/// these indices onto real colors and textures.
struct SkinSelection: Codable, Equatable {

    /// Number of options offered on every axis.
    static let optionCount = 4

    /// Colors used for the blocks.
    var blockPalette: Int
    /// Colors used for the background gradient and the board.
    var surfacePalette: Int
    /// How a block's face is drawn (candy, brick, liquid, metal).
    var blockStyle: Int
    /// The pattern laid over the background and the empty cells.
    var surfaceStyle: Int

    /// The look every new game starts from.
    static let initial = SkinSelection(
        blockPalette: 0,
        surfacePalette: 0,
        blockStyle: 0,
        surfaceStyle: 0
    )

    init(blockPalette: Int, surfacePalette: Int, blockStyle: Int, surfaceStyle: Int) {
        self.blockPalette = SkinSelection.clamp(blockPalette)
        self.surfacePalette = SkinSelection.clamp(surfacePalette)
        self.blockStyle = SkinSelection.clamp(blockStyle)
        self.surfaceStyle = SkinSelection.clamp(surfaceStyle)
    }

    /// Decoding goes through the same clamping, so a corrupted or
    /// forward-dated save can never index past the catalog.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            blockPalette: try container.decodeIfPresent(Int.self, forKey: .blockPalette) ?? 0,
            surfacePalette: try container.decodeIfPresent(Int.self, forKey: .surfacePalette) ?? 0,
            blockStyle: try container.decodeIfPresent(Int.self, forKey: .blockStyle) ?? 0,
            surfaceStyle: try container.decodeIfPresent(Int.self, forKey: .surfaceStyle) ?? 0
        )
    }

    private static func clamp(_ value: Int) -> Int {
        let count = optionCount
        return ((value % count) + count) % count
    }

    /// How many axes differ between two looks.
    func differenceCount(from other: SkinSelection) -> Int {
        var count = 0
        if blockPalette != other.blockPalette { count += 1 }
        if surfacePalette != other.surfacePalette { count += 1 }
        if blockStyle != other.blockStyle { count += 1 }
        if surfaceStyle != other.surfaceStyle { count += 1 }
        return count
    }

    /// A fresh permutation for the next level.
    ///
    /// Any of the four axes may change, but the result always differs on at
    /// least two of them, so a level-up is never so subtle that a child misses
    /// it.
    func next<G: RandomNumberGenerator>(using generator: inout G) -> SkinSelection {
        let range = 0..<SkinSelection.optionCount
        for _ in 0..<24 {
            let candidate = SkinSelection(
                blockPalette: Int.random(in: range, using: &generator),
                surfacePalette: Int.random(in: range, using: &generator),
                blockStyle: Int.random(in: range, using: &generator),
                surfaceStyle: Int.random(in: range, using: &generator)
            )
            if candidate.differenceCount(from: self) >= 2 { return candidate }
        }
        // Deterministic fallback; changes two axes by construction.
        return SkinSelection(
            blockPalette: blockPalette + 1,
            surfacePalette: surfacePalette,
            blockStyle: blockStyle + 1,
            surfaceStyle: surfaceStyle
        )
    }

    func next() -> SkinSelection {
        var generator = SystemRandomNumberGenerator()
        return next(using: &generator)
    }
}
