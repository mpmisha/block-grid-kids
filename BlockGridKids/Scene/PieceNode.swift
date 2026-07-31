import SpriteKit

/// A draggable tray piece. The node's own origin sits at the center of the
/// shape's top-left cell, which makes converting to a board origin trivial.
final class PieceNode: SKNode {

    let piece: Piece
    /// Which tray slot this piece came from.
    var trayIndex: Int
    /// Side length of one cell at full (board) scale.
    let cellSide: CGFloat

    private(set) var blockNodes: [BlockNode] = []

    init(piece: Piece, trayIndex: Int, cellSide: CGFloat) {
        self.piece = piece
        self.trayIndex = trayIndex
        self.cellSide = cellSide
        super.init()
        buildBlocks()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func buildBlocks() {
        for offset in piece.shape.offsets {
            let block = BlockNode(colorIndex: piece.colorIndex, side: cellSide)
            block.position = CGPoint(
                x: CGFloat(offset.col) * cellSide,
                y: -CGFloat(offset.row) * cellSide
            )
            addChild(block)
            blockNodes.append(block)
        }
    }

    // MARK: - Geometry

    var columnCount: Int { piece.shape.width }
    var rowCount: Int { piece.shape.height }

    /// Full-scale footprint of the piece.
    var contentSize: CGSize {
        CGSize(width: CGFloat(columnCount) * cellSide, height: CGFloat(rowCount) * cellSide)
    }

    /// Center of the piece's bounding box, in the node's own coordinates.
    var contentCenter: CGPoint {
        CGPoint(
            x: CGFloat(columnCount - 1) * cellSide / 2,
            y: -CGFloat(rowCount - 1) * cellSide / 2
        )
    }

    // MARK: - Animations

    /// Pops the piece into its tray slot. `targetScale` is the slot's fitted
    /// scale, captured before the node is shrunk for the animation.
    func playIntro(targetScale: CGFloat, delay: TimeInterval) {
        setScale(targetScale * 0.2)
        alpha = 0
        run(.sequence([
            .wait(forDuration: delay),
            .group([
                .fadeIn(withDuration: 0.16),
                .sequence([
                    .scale(to: targetScale * 1.08, duration: 0.16),
                    .scale(to: targetScale, duration: 0.08)
                ])
            ])
        ]))
    }

    /// A longer, sadder wobble for the pieces still stuck in the tray when the
    /// game ends.
    func playGameOverShake() {
        removeAllActions()
        let wobble = SKAction.sequence([
            .rotate(toAngle: -0.10, duration: 0.10),
            .rotate(toAngle: 0.10, duration: 0.14),
            .rotate(toAngle: 0, duration: 0.10)
        ])
        run(.sequence([
            .repeat(wobble, count: 2),
            .group([
                .fadeAlpha(to: 0.45, duration: 0.30),
                .scale(by: 0.86, duration: 0.30)
            ])
        ]))
    }

    func playRejectShake() {
        run(.sequence([
            .moveBy(x: -6, y: 0, duration: 0.045),
            .moveBy(x: 12, y: 0, duration: 0.07),
            .moveBy(x: -12, y: 0, duration: 0.07),
            .moveBy(x: 6, y: 0, duration: 0.045)
        ]))
    }
}
