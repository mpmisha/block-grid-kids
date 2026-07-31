import SpriteKit

/// One beveled block. Backed by a cached texture so it is cheap to create.
final class BlockNode: SKSpriteNode {

    let colorIndex: Int

    init(colorIndex: Int, side: CGFloat) {
        self.colorIndex = colorIndex
        let texture = BlockTextureCache.shared.filledTexture(colorIndex: colorIndex)
        super.init(texture: texture, color: .clear, size: CGSize(width: side, height: side))
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Repaints with the current skin, keeping the block's color slot.
    func refreshSkin() {
        texture = BlockTextureCache.shared.filledTexture(colorIndex: colorIndex)
    }

    /// A quick squash-and-stretch used when a block lands on the board.
    func playLandingBounce(delay: TimeInterval = 0) {
        setScale(0.72)
        alpha = 0.85
        run(.sequence([
            .wait(forDuration: delay),
            .group([
                .fadeAlpha(to: 1, duration: 0.08),
                .sequence([
                    .scale(to: 1.08, duration: 0.09),
                    .scale(to: 1.0, duration: 0.07)
                ])
            ])
        ]))
    }

    /// Drains the block to a flat grey and lets it sag, as part of the
    /// board-wide game-over sweep.
    func playGameOverFade(delay: TimeInterval) {
        removeAllActions()
        run(.sequence([
            .wait(forDuration: delay),
            .group([
                .colorize(with: Theme.gameOverBlock, colorBlendFactor: 0.92, duration: 0.26),
                .fadeAlpha(to: 0.55, duration: 0.26),
                .sequence([
                    .scale(to: 1.12, duration: 0.10),
                    .scale(to: 0.88, duration: 0.16)
                ]),
                .moveBy(x: 0, y: -size.height * 0.08, duration: 0.26)
            ])
        ]))
    }

    /// The pop used when the block's row or column is cleared.
    func playClearAnimation(delay: TimeInterval, completion: @escaping () -> Void) {
        run(.sequence([
            .wait(forDuration: delay),
            .group([
                .scale(to: 1.35, duration: 0.12),
                .fadeAlpha(to: 0.9, duration: 0.12)
            ]),
            .group([
                .scale(to: 0.05, duration: 0.16),
                .fadeOut(withDuration: 0.16),
                .rotate(byAngle: .pi / 5, duration: 0.16)
            ]),
            .removeFromParent()
        ]), completion: completion)
    }
}
