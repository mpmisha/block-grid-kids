import SpriteKit

/// Score, best score and the settings button.
final class HUDNode: SKNode {

    private let scoreLabel = SKLabelNode(fontNamed: Theme.displayFont)
    private let bestLabel = SKLabelNode(fontNamed: Theme.bodyFont)
    private let crownLabel = SKLabelNode(fontNamed: Theme.displayFont)
    private(set) var settingsButton: ButtonNode!

    private var width: CGFloat = 0

    init(width: CGFloat, onSettingsTapped: @escaping () -> Void) {
        super.init()
        self.width = width

        crownLabel.text = "\u{1F451}"
        crownLabel.fontSize = 20
        crownLabel.verticalAlignmentMode = .center
        crownLabel.horizontalAlignmentMode = .left
        addChild(crownLabel)

        bestLabel.fontSize = 19
        bestLabel.fontColor = Theme.crownGold
        bestLabel.verticalAlignmentMode = .center
        bestLabel.horizontalAlignmentMode = .left
        addChild(bestLabel)

        scoreLabel.fontSize = 52
        scoreLabel.fontColor = Theme.primaryText
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.horizontalAlignmentMode = .center
        addChild(scoreLabel)

        settingsButton = ButtonNode(
            title: "\u{2699}\u{FE0E}",
            size: CGSize(width: 46, height: 46),
            style: .secondary,
            fontSize: 24,
            action: onSettingsTapped
        )
        addChild(settingsButton)

        layout(width: width)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func layout(width: CGFloat) {
        self.width = width
        let sidePadding: CGFloat = 22

        crownLabel.position = CGPoint(x: -width / 2 + sidePadding, y: 22)
        bestLabel.position = CGPoint(x: -width / 2 + sidePadding + 26, y: 22)
        scoreLabel.position = CGPoint(x: 0, y: -14)
        settingsButton.position = CGPoint(x: width / 2 - sidePadding - 23, y: 22)
    }

    // MARK: - Updates

    func setScore(_ score: Int, animated: Bool) {
        scoreLabel.text = "\(score)"
        guard animated else { return }
        scoreLabel.removeAction(forKey: "pulse")
        scoreLabel.run(.sequence([
            .scale(to: 1.18, duration: 0.09),
            .scale(to: 1.0, duration: 0.11)
        ]), withKey: "pulse")
    }

    func setBestScore(_ best: Int) {
        bestLabel.text = "\(best)"
    }

    func celebrateNewBest() {
        bestLabel.removeAction(forKey: "celebrate")
        crownLabel.removeAction(forKey: "celebrate")
        let pulse = SKAction.sequence([
            .scale(to: 1.3, duration: 0.12),
            .scale(to: 1.0, duration: 0.14)
        ])
        bestLabel.run(pulse, withKey: "celebrate")
        crownLabel.run(pulse, withKey: "celebrate")
    }
}
