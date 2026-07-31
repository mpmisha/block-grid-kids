import SpriteKit

/// The 8x8 grid: backdrop, empty cells, placed blocks and the drop preview.
/// The node is centered on itself, so cell `(0, 0)` sits at the top-left.
final class BoardNode: SKNode {

    private(set) var cellSide: CGFloat

    private let backdrop = SKShapeNode()
    private let emptyCellLayer = SKNode()
    private let blockLayer = SKNode()
    private let ghostLayer = SKNode()

    private var blockNodes: [GridPosition: BlockNode] = [:]

    init(cellSide: CGFloat) {
        self.cellSide = cellSide
        super.init()

        blockLayer.zPosition = Theme.Layer.blocks
        ghostLayer.zPosition = Theme.Layer.ghost
        addChild(backdrop)
        addChild(emptyCellLayer)
        addChild(blockLayer)
        addChild(ghostLayer)

        rebuildStaticParts()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Geometry

    var boardSide: CGFloat { cellSide * CGFloat(Board.size) }

    /// Center point of a cell, in this node's coordinate space.
    func point(for position: GridPosition) -> CGPoint {
        let half = CGFloat(Board.size - 1) / 2
        return CGPoint(
            x: (CGFloat(position.col) - half) * cellSide,
            y: (half - CGFloat(position.row)) * cellSide
        )
    }

    /// Nearest cell to a point in this node's coordinate space. The result can
    /// be out of bounds; callers validate it against the board.
    func position(nearestTo point: CGPoint) -> GridPosition {
        let half = CGFloat(Board.size - 1) / 2
        let col = (point.x / cellSide + half).rounded()
        let row = (half - point.y / cellSide).rounded()
        return GridPosition(row: Int(row), col: Int(col))
    }

    func updateCellSide(_ newValue: CGFloat) {
        guard newValue != cellSide else { return }
        cellSide = newValue
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
        for row in 0..<Board.size {
            for col in 0..<Board.size {
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
        for row in 0..<Board.size {
            for col in 0..<Board.size {
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

    /// Flashes the rows and columns that are about to clear.
    func flashLines(rows: [Int], columns: [Int]) {
        var positions: Set<GridPosition> = []
        for row in rows {
            for col in 0..<Board.size {
                positions.insert(GridPosition(row: row, col: col))
            }
        }
        for col in columns {
            for row in 0..<Board.size {
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
}
