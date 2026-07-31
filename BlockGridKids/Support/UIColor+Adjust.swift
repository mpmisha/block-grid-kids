import UIKit

extension UIColor {

    /// Returns the same hue with brightness scaled by `factor`.
    /// Values below `1` darken, values above `1` lighten.
    func adjustingBrightness(by factor: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        guard getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return self
        }
        return UIColor(
            hue: hue,
            saturation: saturation,
            brightness: max(0, min(1, brightness * factor)),
            alpha: alpha
        )
    }

    /// Blends toward white by `amount` (0...1).
    func lightened(_ amount: CGFloat) -> UIColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return self }

        let clamped = max(0, min(1, amount))
        return UIColor(
            red: red + (1 - red) * clamped,
            green: green + (1 - green) * clamped,
            blue: blue + (1 - blue) * clamped,
            alpha: alpha
        )
    }
}
