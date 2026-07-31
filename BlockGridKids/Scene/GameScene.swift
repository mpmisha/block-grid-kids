import SpriteKit
import UIKit

/// The single scene that renders and drives the whole game.
final class GameScene: SKScene {

    // MARK: - Model

    private let engine = GameEngine(boardSize: SettingsStore.shared.boardSize)
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
        /// Whether the current hover would clear at least one line. Tracked so
        /// the hint haptic only fires when the answer changes.
        var isPreviewingClear = false
    }

    private var trayPieceNodes: [Int: PieceNode] = [:]
    private var trayPieceScales: [Int: CGFloat] = [:]
    private var drag: DragState?
    private var isPresentingGameOver = false
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
        // the board's rows plus 3 tray rows.
        let boardSizeInCells = engine.board.size
        let boardMaxWidth = size.width - horizontalPadding * 2
        let verticalBudget = size.height
            - insets.top - insets.bottom
            - hudHeight - gapTop - gapBetweenBoardAndTray - gapBottom
        let trayRowUnits: CGFloat = 3.0

        cellSide = max(18, min(boardMaxWidth / CGFloat(boardSizeInCells),
                               verticalBudget / (CGFloat(boardSizeInCells) + trayRowUnits)))
        let boardSide = cellSide * CGFloat(boardSizeInCells)
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
            boardNode = BoardNode(cellSide: cellSide, boardSize: boardSizeInCells)
            boardNode.zPosition = Theme.Layer.board
            addChild(boardNode)
        } else {
            boardNode.updateGeometry(cellSide: cellSide, boardSize: boardSizeInCells)
        }
        boardNode.synchronize(with: engine.board)
        boardNode.position = CGPoint(x: size.width / 2, y: boardTop - boardSide / 2)

        let trayCenterY = boardTop - boardSide - gapBetweenBoardAndTray - trayHeight / 2
        traySlotSize = CGSize(width: size.width / CGFloat(GameConfiguration.traySize) - 10,
                              height: trayHeight)
        traySlotCenters = (0..<GameConfiguration.traySize).map { index in
            let step = size.width / CGFloat(GameConfiguration.traySize)
            return CGPoint(x: step * (CGFloat(index) + 0.5), y: trayCenterY)
        }

        hud.setScore(engine.score, animated: false)
        hud.setBestScore(engine.visibleBestScore)

        rebuildTray(animated: false)

        if engine.isGameOver && activeOverlay == nil {
            presentGameOver(isNewBest: false, animateBoard: false)
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
        let maxWidth = traySlotSize.width * 0.86
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

        if let segment = pendingSegment {
            pendingSegment = nil
            if let value = segment.value(at: location) {
                segment.select(value, notify: true)
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
        pendingSegment = nil
        cancelDrag(returnPiece: true)
    }

    // MARK: - Overlay touches

    private var pendingToggle: ToggleRowNode?
    private var pendingSegment: SegmentedRowNode?

    private func handleOverlayTouchBegan(overlay: OverlayNode, at location: CGPoint) {
        for segment in overlay.interactiveSegments where segment.containsTouch(location) {
            pendingSegment = segment
            return
        }
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

            // Preview which lines this drop would clear, so the player can see
            // the reward before committing to the move.
            let lines = engine.linesCompleted(byPieceAt: state.trayIndex, origin: origin)
            let willClear = !lines.rows.isEmpty || !lines.columns.isEmpty
            boardNode.showClearHint(rows: lines.rows, columns: lines.columns)
            if willClear && !state.isPreviewingClear {
                Haptics.pickUp()
            }
            state.isPreviewingClear = willClear
        } else {
            state.validOrigin = nil
            state.isPreviewingClear = false
            boardNode.hideGhost()
            boardNode.hideClearHint()
        }
        drag = state
    }

    private func finishDrag(at location: CGPoint) {
        guard let state = drag else { return }
        boardNode.hideGhost()
        boardNode.hideClearHint()

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
        boardNode.hideClearHint()
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
                    self?.presentGameOver(isNewBest: result.isNewBestScore, animateBoard: true)
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

        var panel: SettingsPanelNode!
        panel = SettingsPanelNode(
            sceneSize: size,
            bestScore: engine.visibleBestScore,
            boardSize: engine.boardSize,
            onBoardSizeChange: { [weak self] newSize in
                guard let self else { return }
                self.changeBoardSize(to: newSize)
                panel?.updateBestScore(self.engine.visibleBestScore)
            },
            onNewGame: { [weak self] in
                self?.dismissOverlay()
                self?.startNewGame()
            },
            onResetBest: { [weak self] in
                guard let self else { return }
                self.engine.resetBestScore()
                self.hud.setBestScore(self.engine.visibleBestScore)
            },
            onClose: { [weak self] in
                self?.dismissOverlay()
            }
        )
        showOverlay(panel)
    }

    /// Ends the run. When `animateBoard` is true the board first plays its
    /// drain-and-sag sweep and the leftover tray pieces shake, so the player
    /// sees *why* the game stopped before the panel covers everything up.
    private func presentGameOver(isNewBest: Bool, animateBoard: Bool) {
        guard activeOverlay == nil, !isPresentingGameOver else { return }
        isPresentingGameOver = true
        Haptics.gameOver()
        SoundPlayer.shared.play(.gameOver)
        stateStore.clear()

        let showPanel = { [weak self] in
            guard let self else { return }
            self.isPresentingGameOver = false
            guard self.activeOverlay == nil else { return }

            let panel = GameOverPanelNode(
                sceneSize: self.size,
                score: self.engine.score,
                bestScore: self.engine.bestScore,
                isNewBest: isNewBest
            ) { [weak self] in
                self?.dismissOverlay()
                self?.startNewGame()
            }
            self.showOverlay(panel)
        }

        guard animateBoard else {
            showPanel()
            return
        }

        for node in trayPieceNodes.values {
            node.playGameOverShake()
        }
        Effects.praise("No Moves Left", at: CGPoint(x: size.width / 2, y: boardNode.position.y), in: effectLayer)
        boardNode.playGameOverSweep(completion: showPanel)
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
        pendingSegment = nil
        overlay.dismiss()
    }

    // MARK: - Game flow

    private func startNewGame() {
        engine.startNewGame()
        stateStore.clear()
        isPresentingGameOver = false
        boardNode.cancelGameOverSweep()
        boardNode.removeAllBlocks()
        boardNode.hideGhost()
        boardNode.hideClearHint()
        hud.setScore(0, animated: false)
        hud.setBestScore(engine.visibleBestScore)
        rebuildTray(animated: true)
    }

    /// Switches the playfield between the offered sizes. The current run cannot
    /// survive the change, so this always starts a fresh game.
    private func changeBoardSize(to newSize: Int) {
        guard engine.changeBoardSize(to: newSize) else { return }
        SettingsStore.shared.boardSize = newSize
        stateStore.clear()
        isPresentingGameOver = false
        boardNode.cancelGameOverSweep()
        performLayout(force: true)
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
