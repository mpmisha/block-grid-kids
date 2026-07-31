import SpriteKit

/// A rounded, chunky, kid-sized button with press feedback.
final class ButtonNode: SKNode {

    enum Style {
        case primary
        case secondary
        case danger

        var fillColor: UIColor {
            switch self {
            case .primary: return Theme.buttonPrimary
            case .secondary: return Theme.buttonSecondary
            case .danger: return Theme.buttonDanger
            }
        }
    }

    private let background = SKShapeNode()
    private let label = SKLabelNode(fontNamed: Theme.displayFont)
    private let buttonSize: CGSize
    private let action: () -> Void

    private(set) var isPressed = false

    init(title: String,
         size: CGSize,
         style: Style = .primary,
         fontSize: CGFloat? = nil,
         action: @escaping () -> Void) {
        self.buttonSize = size
        self.action = action
        super.init()

        isUserInteractionEnabled = false

        let rect = CGRect(origin: CGPoint(x: -size.width / 2, y: -size.height / 2), size: size)
        let radius = size.height * 0.32
        background.path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        background.fillColor = style.fillColor
        background.strokeColor = style.fillColor.lightened(0.35)
        background.lineWidth = 2
        addChild(background)

        label.text = title
        label.fontSize = fontSize ?? min(size.height * 0.42, 24)
        label.fontColor = Theme.primaryText
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 1
        addChild(label)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var title: String {
        get { label.text ?? "" }
        set { label.text = newValue }
    }

    /// Generous hit area so small fingers connect reliably.
    /// `point` is expressed in scene coordinates.
    func containsTouch(_ point: CGPoint) -> Bool {
        guard let scene else { return false }
        let padding: CGFloat = 10
        let rect = CGRect(
            x: -buttonSize.width / 2 - padding,
            y: -buttonSize.height / 2 - padding,
            width: buttonSize.width + padding * 2,
            height: buttonSize.height + padding * 2
        )
        return rect.contains(convert(point, from: scene))
    }

    func setPressed(_ pressed: Bool) {
        guard pressed != isPressed else { return }
        isPressed = pressed
        removeAction(forKey: "press")
        run(.scale(to: pressed ? 0.94 : 1.0, duration: 0.07), withKey: "press")
    }

    func activate() {
        SoundPlayer.shared.play(.button)
        Haptics.pickUp()
        action()
    }
}
