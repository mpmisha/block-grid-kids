import UIKit

/// Light wrapper around the haptic engines, gated by the settings toggle.
enum Haptics {

    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let notification = UINotificationFeedbackGenerator()

    private static var isEnabled: Bool { SettingsStore.shared.areHapticsEnabled }

    static func prepare() {
        guard isEnabled else { return }
        lightImpact.prepare()
        mediumImpact.prepare()
    }

    static func pickUp() {
        guard isEnabled else { return }
        lightImpact.impactOccurred(intensity: 0.6)
    }

    static func place() {
        guard isEnabled else { return }
        mediumImpact.impactOccurred()
    }

    static func clearLines() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }

    static func invalid() {
        guard isEnabled else { return }
        lightImpact.impactOccurred(intensity: 0.4)
    }

    static func gameOver() {
        guard isEnabled else { return }
        notification.notificationOccurred(.warning)
    }
}
