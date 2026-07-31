import SpriteKit
import UIKit

/// All colors, fonts and metrics in one place so the look can be retuned
/// without touching gameplay code.
enum Theme {

    // MARK: - Palette

    /// The eight block colors. Bright, saturated and easy to tell apart.
    static let blockColors: [UIColor] = [
        UIColor(red: 0.60, green: 0.40, blue: 0.93, alpha: 1),   // purple
        UIColor(red: 0.32, green: 0.79, blue: 0.40, alpha: 1),   // green
        UIColor(red: 0.98, green: 0.60, blue: 0.20, alpha: 1),   // orange
        UIColor(red: 0.26, green: 0.62, blue: 0.97, alpha: 1),   // blue
        UIColor(red: 0.97, green: 0.40, blue: 0.65, alpha: 1),   // pink
        UIColor(red: 0.99, green: 0.83, blue: 0.25, alpha: 1),   // yellow
        UIColor(red: 0.25, green: 0.82, blue: 0.82, alpha: 1),   // cyan
        UIColor(red: 0.95, green: 0.36, blue: 0.36, alpha: 1)    // red
    ]

    static func blockColor(_ index: Int) -> UIColor {
        guard !blockColors.isEmpty else { return .systemPurple }
        let safeIndex = ((index % blockColors.count) + blockColors.count) % blockColors.count
        return blockColors[safeIndex]
    }

    // MARK: - Surfaces

    static let backgroundTop = UIColor(red: 0.36, green: 0.47, blue: 0.86, alpha: 1)
    static let backgroundBottom = UIColor(red: 0.22, green: 0.26, blue: 0.60, alpha: 1)

    static let boardBackground = UIColor(red: 0.16, green: 0.18, blue: 0.32, alpha: 0.55)
    static let emptyCell = UIColor(red: 0.20, green: 0.22, blue: 0.36, alpha: 0.95)
    static let emptyCellStroke = UIColor(white: 1.0, alpha: 0.06)

    static let ghostFill = UIColor(white: 1.0, alpha: 0.22)
    static let ghostStroke = UIColor(white: 1.0, alpha: 0.45)

    static let panelBackground = UIColor(red: 0.20, green: 0.23, blue: 0.42, alpha: 1)
    static let panelStroke = UIColor(white: 1.0, alpha: 0.18)
    static let scrim = UIColor(red: 0.06, green: 0.07, blue: 0.16, alpha: 0.68)

    static let primaryText = UIColor.white
    static let secondaryText = UIColor(white: 1.0, alpha: 0.75)
    static let crownGold = UIColor(red: 1.0, green: 0.80, blue: 0.24, alpha: 1)

    static let buttonPrimary = UIColor(red: 0.34, green: 0.78, blue: 0.44, alpha: 1)
    static let buttonSecondary = UIColor(red: 0.36, green: 0.42, blue: 0.68, alpha: 1)
    static let buttonDanger = UIColor(red: 0.93, green: 0.40, blue: 0.42, alpha: 1)
    static let toggleOn = UIColor(red: 0.34, green: 0.78, blue: 0.44, alpha: 1)
    static let toggleOff = UIColor(white: 1.0, alpha: 0.22)

    // MARK: - Metrics

    static let boardCornerRadiusRatio: CGFloat = 0.14
    static let blockCornerRadiusRatio: CGFloat = 0.22
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
