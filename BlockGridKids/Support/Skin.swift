import UIKit

/// How a block's face is painted.
enum BlockStyle: Int, CaseIterable {
    /// The original glossy candy bevel.
    case candy
    /// Stacked brick courses with darker mortar joints.
    case brick
    /// Wet, rounded look with a bright caustic highlight.
    case liquid
    /// Brushed metal with a vertical sheen and a diagonal streak.
    case metal
}

/// The pattern laid over the background gradient and the empty board cells.
enum SurfaceStyle: Int, CaseIterable {
    case plain
    case dots
    case stripes
    case waves
}

/// Eight block colors that share a mood.
struct BlockPalette {
    let name: String
    let colors: [UIColor]
}

/// The colors of everything behind the blocks.
struct SurfacePalette {
    let name: String
    let backgroundTop: UIColor
    let backgroundBottom: UIColor
    let boardBackground: UIColor
    let emptyCell: UIColor
    /// Tint used for the background pattern; always low alpha.
    let pattern: UIColor
}

/// Resolves a `SkinSelection` into concrete colors and styles.
///
/// Everything drawing-related reads the current skin from here, so changing
/// the look is a single assignment followed by a texture refresh.
enum SkinCatalog {

    // MARK: - Block palettes

    static let blockPalettes: [BlockPalette] = [
        BlockPalette(name: "Candy", colors: [
            UIColor(red: 0.60, green: 0.40, blue: 0.93, alpha: 1),
            UIColor(red: 0.32, green: 0.79, blue: 0.40, alpha: 1),
            UIColor(red: 0.98, green: 0.60, blue: 0.20, alpha: 1),
            UIColor(red: 0.26, green: 0.62, blue: 0.97, alpha: 1),
            UIColor(red: 0.97, green: 0.40, blue: 0.65, alpha: 1),
            UIColor(red: 0.99, green: 0.83, blue: 0.25, alpha: 1),
            UIColor(red: 0.25, green: 0.82, blue: 0.82, alpha: 1),
            UIColor(red: 0.95, green: 0.36, blue: 0.36, alpha: 1)
        ]),
        BlockPalette(name: "Sunset", colors: [
            UIColor(red: 0.98, green: 0.42, blue: 0.35, alpha: 1),
            UIColor(red: 0.99, green: 0.72, blue: 0.24, alpha: 1),
            UIColor(red: 0.94, green: 0.34, blue: 0.56, alpha: 1),
            UIColor(red: 0.74, green: 0.38, blue: 0.80, alpha: 1),
            UIColor(red: 0.99, green: 0.86, blue: 0.42, alpha: 1),
            UIColor(red: 0.93, green: 0.53, blue: 0.24, alpha: 1),
            UIColor(red: 0.86, green: 0.27, blue: 0.42, alpha: 1),
            UIColor(red: 0.99, green: 0.62, blue: 0.56, alpha: 1)
        ]),
        BlockPalette(name: "Ocean", colors: [
            UIColor(red: 0.20, green: 0.72, blue: 0.86, alpha: 1),
            UIColor(red: 0.30, green: 0.85, blue: 0.72, alpha: 1),
            UIColor(red: 0.34, green: 0.55, blue: 0.93, alpha: 1),
            UIColor(red: 0.56, green: 0.86, blue: 0.95, alpha: 1),
            UIColor(red: 0.16, green: 0.60, blue: 0.63, alpha: 1),
            UIColor(red: 0.62, green: 0.52, blue: 0.93, alpha: 1),
            UIColor(red: 0.42, green: 0.88, blue: 0.60, alpha: 1),
            UIColor(red: 0.96, green: 0.79, blue: 0.44, alpha: 1)
        ]),
        BlockPalette(name: "Neon", colors: [
            UIColor(red: 0.99, green: 0.20, blue: 0.62, alpha: 1),
            UIColor(red: 0.56, green: 0.96, blue: 0.22, alpha: 1),
            UIColor(red: 0.15, green: 0.92, blue: 0.92, alpha: 1),
            UIColor(red: 0.70, green: 0.30, blue: 0.99, alpha: 1),
            UIColor(red: 0.99, green: 0.91, blue: 0.16, alpha: 1),
            UIColor(red: 0.99, green: 0.46, blue: 0.10, alpha: 1),
            UIColor(red: 0.25, green: 0.56, blue: 0.99, alpha: 1),
            UIColor(red: 0.99, green: 0.28, blue: 0.30, alpha: 1)
        ])
    ]

    // MARK: - Surface palettes

    static let surfacePalettes: [SurfacePalette] = [
        SurfacePalette(
            name: "Twilight",
            backgroundTop: UIColor(red: 0.36, green: 0.47, blue: 0.86, alpha: 1),
            backgroundBottom: UIColor(red: 0.22, green: 0.26, blue: 0.60, alpha: 1),
            boardBackground: UIColor(red: 0.16, green: 0.18, blue: 0.32, alpha: 0.55),
            emptyCell: UIColor(red: 0.20, green: 0.22, blue: 0.36, alpha: 0.95),
            pattern: UIColor(white: 1.0, alpha: 0.07)
        ),
        SurfacePalette(
            name: "Grape",
            backgroundTop: UIColor(red: 0.54, green: 0.34, blue: 0.82, alpha: 1),
            backgroundBottom: UIColor(red: 0.26, green: 0.14, blue: 0.44, alpha: 1),
            boardBackground: UIColor(red: 0.21, green: 0.12, blue: 0.35, alpha: 0.58),
            emptyCell: UIColor(red: 0.28, green: 0.18, blue: 0.44, alpha: 0.95),
            pattern: UIColor(red: 1.0, green: 0.86, blue: 0.60, alpha: 0.08)
        ),
        SurfacePalette(
            name: "Forest",
            backgroundTop: UIColor(red: 0.20, green: 0.64, blue: 0.56, alpha: 1),
            backgroundBottom: UIColor(red: 0.07, green: 0.28, blue: 0.30, alpha: 1),
            boardBackground: UIColor(red: 0.06, green: 0.21, blue: 0.23, alpha: 0.58),
            emptyCell: UIColor(red: 0.11, green: 0.28, blue: 0.30, alpha: 0.95),
            pattern: UIColor(red: 0.80, green: 1.0, blue: 0.86, alpha: 0.08)
        ),
        SurfacePalette(
            name: "Ember",
            backgroundTop: UIColor(red: 0.70, green: 0.33, blue: 0.30, alpha: 1),
            backgroundBottom: UIColor(red: 0.30, green: 0.12, blue: 0.19, alpha: 1),
            boardBackground: UIColor(red: 0.24, green: 0.10, blue: 0.15, alpha: 0.58),
            emptyCell: UIColor(red: 0.33, green: 0.16, blue: 0.21, alpha: 0.95),
            pattern: UIColor(red: 1.0, green: 0.82, blue: 0.55, alpha: 0.09)
        )
    ]

    // MARK: - Current skin

    private(set) static var selection: SkinSelection = .initial

    /// Bumped on every change so texture caches know to throw their contents
    /// away without having to compare the whole selection.
    private(set) static var revision: Int = 0

    /// Returns `true` when the look actually changed.
    @discardableResult
    static func apply(_ newSelection: SkinSelection) -> Bool {
        guard newSelection != selection else { return false }
        selection = newSelection
        revision += 1
        return true
    }

    static func reset() {
        apply(.initial)
    }

    static var blockPalette: BlockPalette {
        blockPalettes[selection.blockPalette % blockPalettes.count]
    }

    static var surfacePalette: SurfacePalette {
        surfacePalettes[selection.surfacePalette % surfacePalettes.count]
    }

    static var blockStyle: BlockStyle {
        BlockStyle(rawValue: selection.blockStyle % BlockStyle.allCases.count) ?? .candy
    }

    static var surfaceStyle: SurfaceStyle {
        SurfaceStyle(rawValue: selection.surfaceStyle % SurfaceStyle.allCases.count) ?? .plain
    }
}
