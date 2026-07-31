import SpriteKit

/// The only menu in the game: the board size, two toggles, a new game, and a
/// guarded reset of the best score.
final class SettingsPanelNode: OverlayNode {

    private var soundToggle: ToggleRowNode!
    private var hapticsToggle: ToggleRowNode!
    private var sizeRow: SegmentedRowNode!
    private var newGameButton: ButtonNode!
    private var resetButton: ButtonNode!
    private var closeButton: ButtonNode!
    private var bestLabel: SKLabelNode!

    private var isResetArmed = false

    private let onNewGame: () -> Void
    private let onResetBest: () -> Void
    private let onClose: () -> Void
    private let onBoardSizeChange: (Int) -> Void

    init(sceneSize: CGSize,
         bestScore: Int,
         boardSize: Int,
         onBoardSizeChange: @escaping (Int) -> Void,
         onNewGame: @escaping () -> Void,
         onResetBest: @escaping () -> Void,
         onClose: @escaping () -> Void) {
        self.onNewGame = onNewGame
        self.onResetBest = onResetBest
        self.onClose = onClose
        self.onBoardSizeChange = onBoardSizeChange

        let width = min(330, sceneSize.width - 48)
        super.init(sceneSize: sceneSize, panelSize: CGSize(width: width, height: 452))

        let contentWidth = width - 56
        let buttonSize = CGSize(width: contentWidth, height: 52)

        let title = makeTitleLabel("Settings")
        title.position = CGPoint(x: 0, y: 186)
        card.addChild(title)

        bestLabel = makeBodyLabel("Best score: \(bestScore)", fontSize: 17, color: Theme.crownGold)
        bestLabel.position = CGPoint(x: 0, y: 152)
        card.addChild(bestLabel)

        sizeRow = SegmentedRowNode(
            title: "Board",
            values: Board.availableSizes,
            titles: Board.availableSizes.map { "\($0)x\($0)" },
            selected: boardSize,
            width: contentWidth
        ) { [weak self] size in
            self?.onBoardSizeChange(size)
        }
        sizeRow.position = CGPoint(x: 0, y: 104)
        sizeRow.zPosition = 2
        card.addChild(sizeRow)

        soundToggle = ToggleRowNode(
            title: "Sound",
            isOn: SettingsStore.shared.isSoundEnabled,
            width: contentWidth
        ) { isOn in
            SettingsStore.shared.isSoundEnabled = isOn
        }
        soundToggle.position = CGPoint(x: 0, y: 52)
        soundToggle.zPosition = 2
        card.addChild(soundToggle)

        hapticsToggle = ToggleRowNode(
            title: "Vibration",
            isOn: SettingsStore.shared.areHapticsEnabled,
            width: contentWidth
        ) { isOn in
            SettingsStore.shared.areHapticsEnabled = isOn
        }
        hapticsToggle.position = CGPoint(x: 0, y: 4)
        hapticsToggle.zPosition = 2
        card.addChild(hapticsToggle)

        newGameButton = ButtonNode(title: "New Game", size: buttonSize, style: .primary) { [weak self] in
            self?.onNewGame()
        }
        newGameButton.position = CGPoint(x: 0, y: -60)
        newGameButton.zPosition = 2
        card.addChild(newGameButton)

        resetButton = ButtonNode(title: "Reset Best Score", size: buttonSize, style: .danger) { [weak self] in
            self?.handleResetTapped()
        }
        resetButton.position = CGPoint(x: 0, y: -122)
        resetButton.zPosition = 2
        card.addChild(resetButton)

        closeButton = ButtonNode(title: "Close", size: buttonSize, style: .secondary) { [weak self] in
            self?.onClose()
        }
        closeButton.position = CGPoint(x: 0, y: -184)
        closeButton.zPosition = 2
        card.addChild(closeButton)
    }

    /// Called after the scene has switched board size, so the panel can show
    /// the best score that belongs to the newly selected board.
    func updateBestScore(_ value: Int) {
        bestLabel.text = "Best score: \(value)"
    }

    override var interactiveSegments: [SegmentedRowNode] {
        [sizeRow]
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var interactiveButtons: [ButtonNode] {
        [newGameButton, resetButton, closeButton]
    }

    override var interactiveToggles: [ToggleRowNode] {
        [soundToggle, hapticsToggle]
    }

    /// The first tap arms the reset, the second performs it. This stops a child
    /// from wiping the high score by accident.
    private func handleResetTapped() {
        if isResetArmed {
            isResetArmed = false
            resetButton.removeAction(forKey: "disarm")
            resetButton.title = "Reset Best Score"
            bestLabel.text = "Best score: 0"
            onResetBest()
            showResetConfirmation()
            return
        }

        isResetArmed = true
        resetButton.title = "Tap again to confirm"
        resetButton.run(.sequence([
            .wait(forDuration: 4.0),
            .run { [weak self] in
                self?.isResetArmed = false
                self?.resetButton.title = "Reset Best Score"
            }
        ]), withKey: "disarm")
    }

    private func showResetConfirmation() {
        let toast = makeBodyLabel("Best score cleared", fontSize: 16, color: Theme.primaryText)
        toast.position = CGPoint(x: 0, y: 128)
        card.addChild(toast)
        toast.run(.sequence([
            .wait(forDuration: 1.3),
            .fadeOut(withDuration: 0.3),
            .removeFromParent()
        ]))
    }
}
