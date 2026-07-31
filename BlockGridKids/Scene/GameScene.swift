import SpriteKit
import UIKit

/// The single scene that renders and drives the whole game.
final class GameScene: SKScene {

    // MARK: - Model

    private let engine = GameEngine()
    private let stateStore = GameStateStore()

    // MARK: - Nodes

    private let background = BackgroundNode()
    private let trayLayer = SKNode()
    private let effectLayer = SKNode()
    private var hud: HUDNode!
    private var boardNode: BoardNode!

    // MARK: - Layout

    private var cellSide: CGFloat = 40
    private var traySlotCenters: [CGPoint] = []
    private var traySlotSize: CGSize = .zero
    private var lastLaidOutSize: CGSize = .zero

    // MARK: - Interaction state

    private struct DragState {
        let pieceNode: PieceNode
        let trayIndex: Int
        var validOrigin: GridPosition?
    }

    private var trayPieceNodes: [Int: PieceNode] = [:]
    private var trayPieceScales: [Int: CGFloat] = [:]
    private var drag: DragState?
    private var pressedButton: ButtonNode?
    private var activeOverlay: OverlayNode?

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        scaleMode = .resizeFill
        backgroundColor = Theme.backgroundBottom
        anchorPoint = .zero

        SoundPlayer.shared.prepare()
        Haptics.prepare()

        addChild(background)
        trayLayer.zPosition = Theme.Layer.tray
        effectLayer.zPosition = Theme.Layer.effects
        addChild(trayLayer)
        addChild(effectLayer)

        hud = HUDNode(width: size.width) { [weak self] in
            self?.presentSettings()
        }
        hud.zPosition = Theme.Layer.hud
        addChild(hud)

        restoreSavedGameIfPossible()
        performLayout(force: true)
        observeAppLifecycle()
    }

    override func willMove(from view: SKView) {
        saveGameState()
        NotificationCenter.default.removeObserver(self)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard hud != nil else { return }
        performLayout(force: false)
    }

    private func observeAppLifecycle() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillBackground),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    @objc private func handleAppWillBackground() {
        saveGameState()
    }

    // MARK: - Layout

    private func performLayout(force: Bool) {
        guard size.width > 0, size.height > 0 else { return }
        if !force && size == lastLaidOutSize { return }
        lastLaidOutSize = size

        let insets = ScreenInsets.current
        let hudHeight: CGFloat = 76
        let gapTop: CGFloat = 10
        let gapBetweenBoardAndTray: CGFloat = 18
        let gapBottom: CGFloat = 8
        let horizontalPadding: CGFloat = 16

        // The tray band is 3 cells tall, so the vertical budget is divided by
        // 8 board rows plus 3 tray rows.
        let boardMaxWidth = size.width - horizontalPadding * 2
        let verticalBudget = size.height
            - insets.top - insets.bottom
            - hudHeight - gapTop - gapBetweenBoardAndTray - gapBottom
        let trayRowUnits: CGFloat = 3.0

        cellSide = max(18, min(boardMaxWidth / CGFloat(Board.size),
                               verticalBudget / (CGFloat(Board.size) + trayRowUnits)))
        let boardSide = cellSide * CGFloat(Board.size)
        let trayHeight = cellSide * trayRowUnits

        BlockTextureCache.shared.prepare(cellSide: cellSide)

        background.layout(size: size)

        // Vertically center the board + tray block in the space under the HUD.
        let contentTop = size.height - insets.top - hudHeight - gapTop
        let contentBottom = insets.bottom + gapBottom
        let contentHeight = contentTop - contentBottom
        let usedHeight = boardSide + gapBetweenBoardAndTray + trayHeight
        let extraSpace = max(0, contentHeight - usedHeight)
        let boardTop = contentTop - extraSpace / 2

        hud.layout(width: size.width)
        hud.position = CGPoint(x: size.width / 2, y: size.height - insets.top - hudHeight / 2)

        if boardNode == nil {
            boardNode = BoardNode(cellSide: cellSide)
            boardNode.zPosition = Theme.Layer.board
            addChild(boardNode)
            boardNode.synchronize(with: engine.board)
        } else {
            boardNode.updateCellSide(cellSide)
            boardNode.synchronize(with: engine.board)
        }
        boardNode.position = CGPoint(x: size.width / 2, y: boardTop - boardSide / 2)

        let trayCenterY = boardTop - boardSide - gapBetweenBoardAndTray - trayHeight / 2
        traySlotSize = CGSize(width: size.width / CGFloat(GameConfiguration.traySize) - 10,
                              height: trayHeight)
        traySlotCenters = (0..<GameConfiguration.traySize).map { index in
            let step = size.width / CGFloat(GameConfiguration.traySize)
            return CGPoint(x: step * (CGFloat(index) + 0.5), y: trayCenterY)
        }

        hud.setScore(engine.score, animated: false)
        hud.setBestScore(engine.bestScore)

        rebuildTray(animated: false)

        if engine.isGameOver && activeOverlay == nil {
            presentGameOver(isNewBest: false)
        }
    }

    // MARK: - Tray

    private func rebuildTray(animated: Bool) {
        cancelDrag(returnPiece: false)
        trayLayer.removeAllChildren()
        trayPieceNodes.removeAll()
        trayPieceScales.removeAll()

        for index in 0..<GameConfiguration.traySize {
            guard let piece = engine.piece(at: index) else { continue }
            addTrayNode(for: piece, at: index, animated: animated, delay: Double(index) * 0.06)
        }
    }

    private func addTrayNode(for piece: Piece, at index: Int, animated: Bool, delay: TimeInterval) {
        let node = PieceNode(piece: piece, trayIndex: index, cellSide: cellSide)
        let scale = trayScale(for: node)
        node.setScale(scale)
        node.position = trayPosition(for: node, scale: scale, slotIndex: index)
        node.zPosition = Theme.Layer.tray
        trayLayer.addChild(node)

        trayPieceNodes[index] = node
        trayPieceScales[index] = scale

        if animated {
            node.playIntro(targetScale: scale, delay: delay)
        }
    }

    /// Scales the piece so it fits comfortably inside its tray slot.
    private func trayScale(for node: PieceNode) -> CGFloat {
        let maxWidth = traySlotSize.width * 0.90
        let maxHeight = traySlotSize.height * 0.86
        let widthScale = maxWidth / max(1, node.contentSize.width)
        let heightScale = maxHeight / max(1, node.contentSize.height)
        return min(0.75, min(widthScale, heightScale))
    }

    private func trayPosition(for node: PieceNode, scale: CGFloat, slotIndex: Int) -> CGPoint {
        guard traySlotCenters.indices.contains(slotIndex) else { return .zero }
        let center = traySlotCenters[slotIndex]
        let offset = node.contentCenter
        return CGPoint(x: center.x - offset.x * scale, y: center.y - offset.y * scale)
    }

    private func traySlotRect(_ index: Int) -> CGRect {
        guard traySlotCenters.indices.contains(index) else { return .zero }
        let center = traySlotCenters[index]
        return CGRect(
            x: center.x - traySlotSize.width / 2,
            y: center.y - traySlotSize.height / 2,
            width: traySlotSize.width,
            height: traySlotSize.height
        )
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }

        if let overlay = activeOverlay {
            handleOverlayTouchBegan(overlay: overlay, at: location)
            return
        }

        if hud.settingsButton.containsTouch(location) {
            pressedButton = hud.settingsButton
            hud.settingsButton.setPressed(true)
            return
        }

        guard !engine.isGameOver else { return }

        // Tapping anywhere in a tray slot picks up its piece, which is far
        // easier for small fingers than hitting the shape exactly.
        for index in 0..<GameConfiguration.traySize {
            guard trayPieceNodes[index] != nil else { continue }
            if traySlotRect(index).contains(location) {
                beginDrag(trayIndex: index, at: location)
                return
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }

        if let button = pressedButton {
            button.setPressed(button.containsTouch(location))
            return
        }
        guard drag != nil else { return }
        updateDrag(to: location)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }

        if let button = pressedButton {
            let isInside = button.containsTouch(location)
            button.setPressed(false)
            pressedButton = nil
            if isInside {
                button.activate()
            }
            return
        }

        if let toggle = pendingToggle {
            pendingToggle = nil
            if toggle.containsTouch(location) {
                toggle.toggle()
            }
            return
        }

        guard drag != nil else { return }
        finishDrag(at: location)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        pressedButton?.setPressed(false)
        pressedButton = nil
        pendingToggle = nil
        cancelDrag(returnPiece: true)
    }

    // MARK: - Overlay touches

    private var pendingToggle: ToggleRowNode?

    private func handleOverlayTouchBegan(overlay: OverlayNode, at location: CGPoint) {
        for toggle in overlay.interactiveToggles where toggle.containsTouch(location) {
            pendingToggle = toggle
            return
        }
        for button in overlay.interactiveButtons where button.containsTouch(location) {
            pressedButton = button
            button.setPressed(true)
            return
        }
        if overlay.isDismissableByScrim && overlay.isScrimTouch(location) {
            dismissOverlay()
        }
    }

    // MARK: - Dragging

    private func beginDrag(trayIndex: Int, at location: CGPoint) {
        guard let node = trayPieceNodes[trayIndex] else { return }

        node.removeFromParent()
        node.setScale(1.0)
        node.zPosition = Theme.Layer.draggingPiece
        addChild(node)
        node.run(.sequence([
            .scale(to: 1.1, duration: 0.07),
            .scale(to: 1.0, duration: 0.06)
        ]))

        drag = DragState(pieceNode: node, trayIndex: trayIndex, validOrigin: nil)
        updateDrag(to: location)

        Haptics.pickUp()
        SoundPlayer.shared.play(.pickUp)
    }

    private func updateDrag(to location: CGPoint) {
        guard var state = drag else { return }
        let node = state.pieceNode

        // Lift the piece above the finger so it stays visible while dragging.
        let liftHeight = node.contentSize.height / 2 + cellSide * 0.95
        let center = node.contentCenter
        node.position = CGPoint(
            x: location.x - center.x,
            y: location.y + liftHeight - center.y
        )

        let boardLocal = boardNode.convert(node.position, from: self)
        let origin = boardNode.position(nearestTo: boardLocal)

        if engine.canPlace(pieceAt: state.trayIndex, origin: origin) {
            state.validOrigin = origin
            let positions = engine.board.positions(for: node.piece.shape, at: origin)
            boardNode.showGhost(at: positions, colorIndex: node.piece.colorIndex)
        } else {
            state.validOrigin = nil
            boardNode.hideGhost()
        }
        drag = state
    }

    private func finishDrag(at location: CGPoint) {
        guard let state = drag else { return }
        boardNode.hideGhost()

        if let origin = state.validOrigin {
            drag = nil
            place(trayIndex: state.trayIndex, origin: origin, pieceNode: state.pieceNode)
        } else {
            drag = nil
            returnPieceToTray(state.pieceNode, trayIndex: state.trayIndex, shake: true)
            Haptics.invalid()
            SoundPlayer.shared.play(.invalid)
        }
    }

    private func cancelDrag(returnPiece: Bool) {
        guard let state = drag else { return }
        drag = nil
        boardNode.hideGhost()
        if returnPiece {
            returnPieceToTray(state.pieceNode, trayIndex: state.trayIndex, shake: false)
        } else {
            state.pieceNode.removeFromParent()
        }
    }

    private func returnPieceToTray(_ node: PieceNode, trayIndex: Int, shake: Bool) {
        node.removeFromParent()
        trayLayer.addChild(node)
        node.zPosition = Theme.Layer.tray

        let scale = trayPieceScales[trayIndex] ?? trayScale(for: node)
        trayPieceScales[trayIndex] = scale
        trayPieceNodes[trayIndex] = node

        let target = trayPosition(for: node, scale: scale, slotIndex: trayIndex)
        node.run(.group([
            .move(to: target, duration: 0.16),
            .scale(to: scale, duration: 0.16)
        ])) {
            if shake {
                node.playRejectShake()
            }
        }
    }

    // MARK: - Placement

    private func place(trayIndex: Int, origin: GridPosition, pieceNode: PieceNode) {
        let colorIndex = pieceNode.piece.colorIndex
        guard let result = engine.place(pieceAt: trayIndex, origin: origin) else {
            returnPieceToTray(pieceNode, trayIndex: trayIndex, shake: true)
            return
        }

        pieceNode.removeFromParent()
        trayPieceNodes[trayIndex] = nil
        trayPieceScales[trayIndex] = nil

        for (offset, position) in result.placedPositions.enumerated() {
            let block = boardNode.addBlock(at: position, colorIndex: colorIndex)
            block.playLandingBounce(delay: Double(offset) * 0.015)
        }

        Haptics.place()
        SoundPlayer.shared.play(.place)

        hud.setScore(result.totalScore, animated: true)
        if result.isNewBestScore {
            hud.setBestScore(engine.bestScore)
            hud.celebrateNewBest()
        }

        let scorePoint = CGPoint(
            x: boardNode.position.x,
            y: boardNode.position.y + boardNode.boardSide / 2 + 26
        )
        Effects.floatingScore(
            result.breakdown.total,
            at: scorePoint,
            in: effectLayer,
            color: result.didClearLines ? Theme.crownGold : .white
        )

        if result.didClearLines {
            animateClears(result)
        }

        if result.didRefillTray {
            let delay = result.didClearLines ? 0.32 : 0.16
            run(.sequence([
                .wait(forDuration: delay),
                .run { [weak self] in self?.rebuildTray(animated: true) }
            ]))
        }

        if result.isGameOver {
            run(.sequence([
                .wait(forDuration: result.didClearLines ? 0.85 : 0.55),
                .run { [weak self] in
                    self?.presentGameOver(isNewBest: result.isNewBestScore)
                }
            ]))
        }

        saveGameState()
    }

    private func animateClears(_ result: PlacementResult) {
        Haptics.clearLines()
        SoundPlayer.shared.play(result.clearedLineCount > 1 ? .clearCombo : .clearSingle)
        boardNode.flashLines(rows: result.clearedRows, columns: result.clearedColumns)

        for (index, position) in result.clearedPositions.enumerated() {
            let delay = Double(position.col + position.row) * 0.012
            guard let block = boardNode.detachBlock(at: position) else { continue }
            let colorIndex = block.colorIndex
            let scenePoint = boardNode.point(for: position)

            block.playClearAnimation(delay: delay) {}

            // Only every third cell sprays confetti, to keep the node count low.
            if index % 3 == 0 {
                Effects.confettiBurst(
                    at: convert(scenePoint, from: boardNode),
                    colorIndex: colorIndex,
                    cellSide: cellSide,
                    in: effectLayer,
                    delay: delay + 0.1
                )
            }
        }

        if let text = Effects.praiseText(lineCount: result.clearedLineCount, streak: result.streak) {
            Effects.praise(
                text,
                at: CGPoint(x: size.width / 2, y: boardNode.position.y),
                in: effectLayer
            )
        }
    }

    // MARK: - Overlays

    private func presentSettings() {
        guard activeOverlay == nil else { return }
        cancelDrag(returnPiece: true)

        let panel = SettingsPanelNode(
            sceneSize: size,
            bestScore: engine.bestScore,
            onNewGame: { [weak self] in
                self?.dismissOverlay()
                self?.startNewGame()
            },
            onResetBest: { [weak self] in
                guard let self else { return }
                self.engine.resetBestScore()
                self.hud.setBestScore(self.engine.bestScore)
            },
            onClose: { [weak self] in
                self?.dismissOverlay()
            }
        )
        showOverlay(panel)
    }

    private func presentGameOver(isNewBest: Bool) {
        guard activeOverlay == nil else { return }
        Haptics.gameOver()
        SoundPlayer.shared.play(.gameOver)
        stateStore.clear()

        let panel = GameOverPanelNode(
            sceneSize: size,
            score: engine.score,
            bestScore: engine.bestScore,
            isNewBest: isNewBest
        ) { [weak self] in
            self?.dismissOverlay()
            self?.startNewGame()
        }
        showOverlay(panel)
    }

    private func showOverlay(_ overlay: OverlayNode) {
        activeOverlay = overlay
        addChild(overlay)
        overlay.present()
    }

    private func dismissOverlay() {
        guard let overlay = activeOverlay else { return }
        activeOverlay = nil
        pressedButton = nil
        pendingToggle = nil
        overlay.dismiss()
    }

    // MARK: - Game flow

    private func startNewGame() {
        engine.startNewGame()
        stateStore.clear()
        boardNode.removeAllBlocks()
        boardNode.hideGhost()
        hud.setScore(0, animated: false)
        hud.setBestScore(engine.bestScore)
        rebuildTray(animated: true)
    }

    // MARK: - Persistence

    private func restoreSavedGameIfPossible() {
        guard let snapshot = stateStore.loadSnapshot() else { return }
        _ = engine.restore(from: snapshot)
    }

    private func saveGameState() {
        guard !engine.isGameOver else {
            stateStore.clear()
            return
        }
        stateStore.save(engine.makeSnapshot())
    }
}
