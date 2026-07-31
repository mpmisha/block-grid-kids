import SpriteKit

/// Base class for the modal panels. Owns a dimming scrim and a rounded card,
/// and exposes the interactive children so the scene can route touches.
class OverlayNode: SKNode {

    let card = SKShapeNode()
    private let scrim = SKSpriteNode()
    private(set) var panelSize: CGSize

    /// Buttons the scene should hit-test while this overlay is showing.
    var interactiveButtons: [ButtonNode] { [] }
    /// Toggles the scene should hit-test while this overlay is showing.
    var interactiveToggles: [ToggleRowNode] { [] }
    /// When true, tapping the scrim dismisses the overlay.
    var isDismissableByScrim: Bool { true }

    init(sceneSize: CGSize, panelSize: CGSize) {
        self.panelSize = panelSize
        super.init()
        zPosition = Theme.Layer.overlay
        isUserInteractionEnabled = false

        scrim.color = Theme.scrim
        scrim.size = CGSize(width: sceneSize.width * 1.2, height: sceneSize.height * 1.2)
        scrim.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        scrim.zPosition = 0
        addChild(scrim)

        let rect = CGRect(
            x: -panelSize.width / 2,
            y: -panelSize.height / 2,
            width: panelSize.width,
            height: panelSize.height
        )
        card.path = CGPath(roundedRect: rect, cornerWidth: 28, cornerHeight: 28, transform: nil)
        card.fillColor = Theme.panelBackground
        card.strokeColor = Theme.panelStroke
        card.lineWidth = 2
        card.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        card.zPosition = 1
        addChild(card)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Presentation

    func present() {
        alpha = 0
        card.setScale(0.85)
        run(.fadeIn(withDuration: 0.16))
        card.run(.sequence([
            .scale(to: 1.04, duration: 0.14),
            .scale(to: 1.0, duration: 0.08)
        ]))
    }

    func dismiss(completion: (() -> Void)? = nil) {
        run(.sequence([
            .fadeOut(withDuration: 0.14),
            .removeFromParent()
        ]), completion: { completion?() })
        card.run(.scale(to: 0.9, duration: 0.14))
    }

    /// True when the point, in scene coordinates, is outside the card.
    func isScrimTouch(_ point: CGPoint) -> Bool {
        guard let scene else { return false }
        let local = card.convert(point, from: scene)
        let rect = CGRect(
            x: -panelSize.width / 2,
            y: -panelSize.height / 2,
            width: panelSize.width,
            height: panelSize.height
        )
        return !rect.contains(local)
    }

    // MARK: - Helpers for subclasses

    func makeTitleLabel(_ text: String, fontSize: CGFloat = 30) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: Theme.displayFont)
        label.text = text
        label.fontSize = fontSize
        label.fontColor = Theme.primaryText
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 2
        return label
    }

    func makeBodyLabel(_ text: String, fontSize: CGFloat = 18, color: UIColor = Theme.secondaryText) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: Theme.bodyFont)
        label.text = text
        label.fontSize = fontSize
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 2
        return label
    }
}
