import SpriteKit

/// The playfield grid: backdrop, empty cells, placed blocks and the drop
/// preview. The node is centered on itself, so cell `(0, 0)` sits top-left.
final class BoardNode: SKNode {

    private(set) var cellSide: CGFloat
    private(set) var boardSize: Int

    private let backdrop = SKShapeNode()
    private let emptyCellLayer = SKNode()
    private let blockLayer = SKNode()
    private let ghostLayer = SKNode()
    private let clearHintLayer = SKNode()

    private var blockNodes: [GridPosition: BlockNode] = [:]
    /// Identifies the currently drawn clear hint so it is only rebuilt when
    /// the highlighted lines actually change.
    private var clearHintKey = ""

    init(cellSide: CGFloat, boardSize: Int) {
        self.cellSide = cellSide
        self.boardSize = boardSize
        super.init()

        blockLayer.zPosition = Theme.Layer.blocks
        clearHintLayer.zPosition = Theme.Layer.ghost - 1
        ghostLayer.zPosition = Theme.Layer.ghost
        addChild(backdrop)
        addChild(emptyCellLayer)
        addChild(clearHintLayer)
        addChild(blockLayer)
        addChild(ghostLayer)

        rebuildStaticParts()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Geometry

    var boardSide: CGFloat { cellSide * CGFloat(boardSize) }

    /// Center point of a cell, in this node's coordinate space.
    func point(for position: GridPosition) -> CGPoint {
        let half = CGFloat(boardSize - 1) / 2
        return CGPoint(
            x: (CGFloat(position.col) - half) * cellSide,
            y: (half - CGFloat(position.row)) * cellSide
        )
    }

    /// Nearest cell to a point in this node's coordinate space. The result can
    /// be out of bounds; callers validate it against the board.
    func position(nearestTo point: CGPoint) -> GridPosition {
        let half = CGFloat(boardSize - 1) / 2
        let col = (point.x / cellSide + half).rounded()
        let row = (half - point.y / cellSide).rounded()
        return GridPosition(row: Int(row), col: Int(col))
    }

    func updateGeometry(cellSide newCellSide: CGFloat, boardSize newBoardSize: Int) {
        guard newCellSide != cellSide || newBoardSize != boardSize else { return }
        if newBoardSize != boardSize {
            removeAllBlocks()
            hideGhost()
            hideClearHint()
        }
        cellSide = newCellSide
        boardSize = newBoardSize
        rebuildStaticParts()
    }

    private func rebuildStaticParts() {
        let side = boardSide
        let padding = cellSide * 0.14
        let rect = CGRect(
            x: -side / 2 - padding,
            y: -side / 2 - padding,
            width: side + padding * 2,
            height: side + padding * 2
        )
        backdrop.path = CGPath(
            roundedRect: rect,
            cornerWidth: cellSide * 0.35,
            cornerHeight: cellSide * 0.35,
            transform: nil
        )
        backdrop.fillColor = Theme.boardBackground
        backdrop.strokeColor = UIColor(white: 1, alpha: 0.10)
        backdrop.lineWidth = 2
        backdrop.zPosition = Theme.Layer.board

        emptyCellLayer.removeAllChildren()
        let texture = BlockTextureCache.shared.emptyCellTexture()
        for row in 0..<boardSize {
            for col in 0..<boardSize {
                let cell = SKSpriteNode(
                    texture: texture,
                    color: .clear,
                    size: CGSize(width: cellSide, height: cellSide)
                )
                cell.position = point(for: GridPosition(row: row, col: col))
                cell.zPosition = Theme.Layer.board + 1
                emptyCellLayer.addChild(cell)
            }
        }
    }

    // MARK: - Blocks

    @discardableResult
    func addBlock(at position: GridPosition, colorIndex: Int) -> BlockNode {
        removeBlock(at: position)
        let block = BlockNode(colorIndex: colorIndex, side: cellSide)
        block.position = point(for: position)
        blockLayer.addChild(block)
        blockNodes[position] = block
        return block
    }

    func block(at position: GridPosition) -> BlockNode? {
        blockNodes[position]
    }

    func removeBlock(at position: GridPosition) {
        blockNodes[position]?.removeFromParent()
        blockNodes[position] = nil
    }

    /// Detaches a block from bookkeeping while leaving it on screen so a clear
    /// animation can finish playing.
    func detachBlock(at position: GridPosition) -> BlockNode? {
        guard let block = blockNodes[position] else { return nil }
        blockNodes[position] = nil
        return block
    }

    func removeAllBlocks() {
        blockLayer.removeAllChildren()
        blockNodes.removeAll()
    }

    /// Rebuilds every block from the model. Used on restore and new game.
    func synchronize(with board: Board) {
        removeAllBlocks()
        for row in 0..<board.size {
            for col in 0..<board.size {
                let position = GridPosition(row: row, col: col)
                if let colorIndex = board[position] {
                    addBlock(at: position, colorIndex: colorIndex)
                }
            }
        }
    }

    // MARK: - Ghost preview

    /// Shows a translucent preview of where the dragged piece will land.
    func showGhost(at positions: [GridPosition], colorIndex: Int) {
        ghostLayer.removeAllChildren()
        let color = Theme.blockColor(colorIndex)
        for position in positions {
            let size = CGSize(width: cellSide * 0.86, height: cellSide * 0.86)
            let node = SKShapeNode(
                rectOf: size,
                cornerRadius: cellSide * Theme.blockCornerRadiusRatio
            )
            node.fillColor = color.withAlphaComponent(0.38)
            node.strokeColor = color.lightened(0.45).withAlphaComponent(0.85)
            node.lineWidth = max(2, cellSide * 0.05)
            node.position = point(for: position)
            ghostLayer.addChild(node)
        }
    }

    func hideGhost() {
        ghostLayer.removeAllChildren()
    }

    // MARK: - Clear hint

    /// Highlights the rows and columns that the piece being dragged would
    /// clear if it were dropped where it currently hovers. This is the nudge
    /// that teaches a young player to look for complete lines.
    func showClearHint(rows: [Int], columns: [Int]) {
        let key = "r\(rows)c\(columns)"
        guard key != clearHintKey else { return }
        clearHintKey = key
        clearHintLayer.removeAllChildren()
        guard !rows.isEmpty || !columns.isEmpty else { return }

        var positions: Set<GridPosition> = []
        for row in rows {
            for col in 0..<boardSize { positions.insert(GridPosition(row: row, col: col)) }
        }
        for col in columns {
            for row in 0..<boardSize { positions.insert(GridPosition(row: row, col: col)) }
        }

        for position in positions {
            let node = SKShapeNode(
                rectOf: CGSize(width: cellSide * 0.97, height: cellSide * 0.97),
                cornerRadius: cellSide * Theme.blockCornerRadiusRatio
            )
            node.fillColor = Theme.crownGold.withAlphaComponent(0.24)
            node.strokeColor = Theme.crownGold.withAlphaComponent(0.85)
            node.lineWidth = max(1.5, cellSide * 0.05)
            node.position = point(for: position)
            node.blendMode = .add
            clearHintLayer.addChild(node)
        }

        clearHintLayer.removeAllActions()
        clearHintLayer.alpha = 0.55
        clearHintLayer.run(.repeatForever(.sequence([
            .fadeAlpha(to: 1.0, duration: 0.34),
            .fadeAlpha(to: 0.55, duration: 0.34)
        ])))
    }

    func hideClearHint() {
        guard !clearHintKey.isEmpty else { return }
        clearHintKey = ""
        clearHintLayer.removeAllActions()
        clearHintLayer.alpha = 1
        clearHintLayer.removeAllChildren()
    }

    /// Flashes the rows and columns that are about to clear.
    func flashLines(rows: [Int], columns: [Int]) {
        var positions: Set<GridPosition> = []
        for row in rows {
            for col in 0..<boardSize {
                positions.insert(GridPosition(row: row, col: col))
            }
        }
        for col in columns {
            for row in 0..<boardSize {
                positions.insert(GridPosition(row: row, col: col))
            }
        }

        for position in positions {
            let flash = SKShapeNode(
                rectOf: CGSize(width: cellSide, height: cellSide),
                cornerRadius: cellSide * Theme.blockCornerRadiusRatio
            )
            flash.fillColor = UIColor(white: 1, alpha: 0.85)
            flash.strokeColor = .clear
            flash.position = point(for: position)
            flash.zPosition = Theme.Layer.effects
            flash.blendMode = .add
            addChild(flash)
            flash.run(.sequence([
                .fadeAlpha(to: 0, duration: 0.28),
                .removeFromParent()
            ]))
        }
    }

    // MARK: - Game over

    /// Sweeps the board diagonally, draining the colour out of every block, so
    /// it is obvious the run has ended before the panel slides in.
    /// Calls `completion` once the last block has settled.
    func playGameOverSweep(completion: @escaping () -> Void) {
        hideGhost()
        hideClearHint()

        var longestDelay: TimeInterval = 0
        for (position, block) in blockNodes {
            let delay = Double(position.row + position.col) * 0.035
            longestDelay = max(longestDelay, delay)
            block.playGameOverFade(delay: delay)
        }

        let settle = longestDelay + 0.42
        run(.sequence([.wait(forDuration: settle), .run(completion)]), withKey: "gameOverSweep")
    }

    func cancelGameOverSweep() {
        removeAction(forKey: "gameOverSweep")
    }
}
