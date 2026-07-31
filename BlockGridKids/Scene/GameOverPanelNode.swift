import SpriteKit

/// Shown when no piece fits any more. One clear action: play again.
final class GameOverPanelNode: OverlayNode {

    private var playAgainButton: ButtonNode!
    private let onPlayAgain: () -> Void

    init(sceneSize: CGSize,
         score: Int,
         bestScore: Int,
         isNewBest: Bool,
         onPlayAgain: @escaping () -> Void) {
        self.onPlayAgain = onPlayAgain

        let width = min(320, sceneSize.width - 48)
        super.init(sceneSize: sceneSize, panelSize: CGSize(width: width, height: 300))

        let title = makeTitleLabel(isNewBest ? "New Best!" : "No More Moves")
        title.fontSize = isNewBest ? 32 : 26
        title.fontColor = isNewBest ? Theme.crownGold : Theme.primaryText
        title.position = CGPoint(x: 0, y: 104)
        card.addChild(title)

        let emoji = makeTitleLabel(isNewBest ? "\u{1F389}" : "\u{1F9E9}", fontSize: 44)
        emoji.position = CGPoint(x: 0, y: 46)
        card.addChild(emoji)

        let scoreCaption = makeBodyLabel("Your score", fontSize: 15)
        scoreCaption.position = CGPoint(x: 0, y: 4)
        card.addChild(scoreCaption)

        let scoreValue = makeTitleLabel("\(score)", fontSize: 46)
        scoreValue.position = CGPoint(x: 0, y: -34)
        card.addChild(scoreValue)

        let bestValue = makeBodyLabel("\u{1F451} Best: \(bestScore)", fontSize: 17, color: Theme.crownGold)
        bestValue.position = CGPoint(x: 0, y: -70)
        card.addChild(bestValue)

        playAgainButton = ButtonNode(
            title: "Play Again",
            size: CGSize(width: width - 56, height: 54),
            style: .primary
        ) { [weak self] in
            self?.onPlayAgain()
        }
        playAgainButton.position = CGPoint(x: 0, y: -116)
        playAgainButton.zPosition = 2
        card.addChild(playAgainButton)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var interactiveButtons: [ButtonNode] { [playAgainButton] }

    /// The game-over panel must not be dismissible by tapping outside; the
    /// player has to choose to start a new game.
    override var isDismissableByScrim: Bool { false }
}
