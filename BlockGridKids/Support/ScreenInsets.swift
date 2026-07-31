import UIKit

/// Reads the real window safe-area insets so the HUD clears the Dynamic Island
/// and the tray clears the home indicator, with sane fallbacks.
enum ScreenInsets {

    static var current: UIEdgeInsets {
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = windowScenes.flatMap(\.windows)
        let window = windows.first(where: \.isKeyWindow) ?? windows.first

        var insets = window?.safeAreaInsets ?? .zero
        insets.top = max(insets.top, 24)
        insets.bottom = max(insets.bottom, 14)
        return insets
    }
}
