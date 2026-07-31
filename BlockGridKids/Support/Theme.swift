import SpriteKit
import UIKit

/// All colors, fonts and metrics in one place so the look can be retuned
/// without touching gameplay code.
enum Theme {

    // MARK: - Palette
    //
    // The colors below come from the active skin, which changes every time the
    // player clears the whole board. Everything else in this file is fixed
    // chrome that must stay legible no matter which skin is on.

    /// The eight block colors of the current skin.
    static var blockColors: [UIColor] { SkinCatalog.blockPalette.colors }

    static func blockColor(_ index: Int) -> UIColor {
        let colors = blockColors
        guard !colors.isEmpty else { return .systemPurple }
        let safeIndex = ((index % colors.count) + colors.count) % colors.count
        return colors[safeIndex]
    }

    // MARK: - Surfaces

    static var backgroundTop: UIColor { SkinCatalog.surfacePalette.backgroundTop }
    static var backgroundBottom: UIColor { SkinCatalog.surfacePalette.backgroundBottom }

    static var boardBackground: UIColor { SkinCatalog.surfacePalette.boardBackground }
    static var emptyCell: UIColor { SkinCatalog.surfacePalette.emptyCell }
    static let emptyCellStroke = UIColor(white: 1.0, alpha: 0.06)

    static let ghostFill = UIColor(white: 1.0, alpha: 0.22)
    static let ghostStroke = UIColor(white: 1.0, alpha: 0.45)

    static let panelBackground = UIColor(red: 0.20, green: 0.23, blue: 0.42, alpha: 1)
    static let panelStroke = UIColor(white: 1.0, alpha: 0.18)
    static let scrim = UIColor(red: 0.06, green: 0.07, blue: 0.16, alpha: 0.68)

    static let primaryText = UIColor.white
    static let secondaryText = UIColor(white: 1.0, alpha: 0.75)
    static let crownGold = UIColor(red: 1.0, green: 0.80, blue: 0.24, alpha: 1)
    /// Colour blocks drain to during the game-over sweep.
    static let gameOverBlock = UIColor(red: 0.36, green: 0.38, blue: 0.50, alpha: 1)

    static let buttonPrimary = UIColor(red: 0.34, green: 0.78, blue: 0.44, alpha: 1)
    static let buttonSecondary = UIColor(red: 0.36, green: 0.42, blue: 0.68, alpha: 1)
    static let buttonDanger = UIColor(red: 0.93, green: 0.40, blue: 0.42, alpha: 1)
    static let toggleOn = UIColor(red: 0.34, green: 0.78, blue: 0.44, alpha: 1)
    static let toggleOff = UIColor(white: 1.0, alpha: 0.22)

    // MARK: - Metrics

    static let boardCornerRadiusRatio: CGFloat = 0.14
    /// Blocks are drawn edge to edge so neighbours in a shape read as one
    /// solid piece; only the bevel and this small radius separate them.
    static let blockCornerRadiusRatio: CGFloat = 0.16
    static let blockInsetRatio: CGFloat = 0.06

    // MARK: - Fonts

    static let displayFont = "AvenirNext-Heavy"
    static let bodyFont = "AvenirNext-DemiBold"

    // MARK: - Z positions

    enum Layer {
        static let background: CGFloat = -100
        static let bubbles: CGFloat = -90
        static let board: CGFloat = 0
        static let blocks: CGFloat = 10
        static let ghost: CGFloat = 15
        static let tray: CGFloat = 20
        static let hud: CGFloat = 40
        static let effects: CGFloat = 60
        static let draggingPiece: CGFloat = 80
        static let overlay: CGFloat = 100
    }
}
