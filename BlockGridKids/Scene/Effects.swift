import SpriteKit

/// Small celebratory effects: confetti bursts and floating score popups.
enum Effects {

    /// Sprays a handful of colored squares outward from a cleared cell.
    static func confettiBurst(at point: CGPoint,
                              colorIndex: Int,
                              cellSide: CGFloat,
                              in parent: SKNode,
                              delay: TimeInterval = 0) {
        let color = Theme.blockColor(colorIndex)
        let pieceCount = 5

        for _ in 0..<pieceCount {
            let side = cellSide * CGFloat.random(in: 0.14...0.26)
            let confetto = SKSpriteNode(color: color.lightened(CGFloat.random(in: 0...0.4)),
                                        size: CGSize(width: side, height: side))
            confetto.position = point
            confetto.zPosition = Theme.Layer.effects
            confetto.alpha = 0
            parent.addChild(confetto)

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = cellSide * CGFloat.random(in: 0.7...1.9)
            let travel = CGVector(dx: cos(angle) * distance, dy: sin(angle) * distance)
            let duration = TimeInterval.random(in: 0.35...0.6)

            confetto.run(.sequence([
                .wait(forDuration: delay),
                .fadeIn(withDuration: 0.05),
                .group([
                    .move(by: travel, duration: duration),
                    .rotate(byAngle: CGFloat.random(in: -3...3), duration: duration),
                    .sequence([
                        .wait(forDuration: duration * 0.45),
                        .fadeOut(withDuration: duration * 0.55)
                    ]),
                    .scale(to: 0.3, duration: duration)
                ]),
                .removeFromParent()
            ]))
        }
    }

    /// A "+42" that floats up and fades.
    static func floatingScore(_ amount: Int,
                              at point: CGPoint,
                              in parent: SKNode,
                              color: UIColor = .white) {
        guard amount > 0 else { return }
        let label = SKLabelNode(fontNamed: Theme.displayFont)
        label.text = "+\(amount)"
        label.fontSize = 30
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = point
        label.zPosition = Theme.Layer.effects + 5
        label.setScale(0.6)
        parent.addChild(label)

        label.run(.sequence([
            .group([
                .scale(to: 1.15, duration: 0.16),
                .moveBy(x: 0, y: 26, duration: 0.16)
            ]),
            .group([
                .moveBy(x: 0, y: 44, duration: 0.55),
                .fadeOut(withDuration: 0.55),
                .scale(to: 0.9, duration: 0.55)
            ]),
            .removeFromParent()
        ]))
    }

    /// Encouraging word shown for multi-line clears and long streaks.
    static func praise(_ text: String, at point: CGPoint, in parent: SKNode) {
        let label = SKLabelNode(fontNamed: Theme.displayFont)
        label.text = text
        label.fontSize = 34
        label.fontColor = Theme.crownGold
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = point
        label.zPosition = Theme.Layer.effects + 6
        label.setScale(0.3)
        label.alpha = 0
        parent.addChild(label)

        label.run(.sequence([
            .group([
                .fadeIn(withDuration: 0.14),
                .scale(to: 1.12, duration: 0.18)
            ]),
            .scale(to: 1.0, duration: 0.1),
            .wait(forDuration: 0.42),
            .group([
                .fadeOut(withDuration: 0.3),
                .moveBy(x: 0, y: 30, duration: 0.3)
            ]),
            .removeFromParent()
        ]))
    }

    /// Picks the praise word for a clear.
    static func praiseText(lineCount: Int, streak: Int) -> String? {
        if lineCount >= 4 { return "AMAZING!" }
        if lineCount == 3 { return "SUPER!" }
        if lineCount == 2 { return "GREAT!" }
        if streak >= 5 { return "ON FIRE!" }
        if streak >= 3 { return "NICE!" }
        return nil
    }

    // MARK: - Perfect clear

    /// The reward for emptying the whole board: rings racing outward, a
    /// confetti fountain and a big "PERFECT!" banner naming the new level.
    ///
    /// `center` and `boardSide` are in `parent`'s coordinate space.
    static func perfectClearCelebration(at center: CGPoint,
                                        boardSide: CGFloat,
                                        level: Int,
                                        in parent: SKNode) {
        for index in 0..<3 {
            let ring = SKShapeNode(circleOfRadius: boardSide * 0.16)
            ring.fillColor = .clear
            ring.strokeColor = Theme.crownGold
            ring.lineWidth = max(3, boardSide * 0.016)
            ring.position = center
            ring.zPosition = Theme.Layer.effects + 2
            ring.blendMode = .add
            ring.alpha = 0
            parent.addChild(ring)

            ring.run(.sequence([
                .wait(forDuration: Double(index) * 0.14),
                .fadeAlpha(to: 0.9, duration: 0.06),
                .group([
                    .scale(to: 3.2, duration: 0.62),
                    .fadeOut(withDuration: 0.62)
                ]),
                .removeFromParent()
            ]))
        }

        // Fountain of confetti rising from the bottom of the board.
        let colorCount = max(1, Theme.blockColors.count)
        for index in 0..<26 {
            let side = boardSide * CGFloat.random(in: 0.020...0.040)
            let confetto = SKSpriteNode(
                color: Theme.blockColor(index % colorCount),
                size: CGSize(width: side, height: side * CGFloat.random(in: 0.7...1.5))
            )
            confetto.position = CGPoint(
                x: center.x + CGFloat.random(in: -boardSide / 2...boardSide / 2),
                y: center.y - boardSide * 0.45
            )
            confetto.zPosition = Theme.Layer.effects + 1
            confetto.alpha = 0
            parent.addChild(confetto)

            let rise = boardSide * CGFloat.random(in: 0.55...1.05)
            let drift = CGFloat.random(in: -boardSide * 0.18...boardSide * 0.18)
            let duration = TimeInterval.random(in: 0.7...1.15)

            confetto.run(.sequence([
                .wait(forDuration: Double(index) * 0.012),
                .fadeIn(withDuration: 0.06),
                .group([
                    .sequence([
                        .moveBy(x: drift, y: rise, duration: duration * 0.55),
                        .moveBy(x: drift * 0.4, y: -rise * 0.35, duration: duration * 0.45)
                    ]),
                    .rotate(byAngle: CGFloat.random(in: -6...6), duration: duration),
                    .sequence([
                        .wait(forDuration: duration * 0.55),
                        .fadeOut(withDuration: duration * 0.45)
                    ])
                ]),
                .removeFromParent()
            ]))
        }

        let banner = SKNode()
        banner.position = center
        banner.zPosition = Theme.Layer.effects + 8
        banner.setScale(0.3)
        banner.alpha = 0
        parent.addChild(banner)

        let title = SKLabelNode(fontNamed: Theme.displayFont)
        title.text = "PERFECT!"
        title.fontSize = 46
        title.fontColor = Theme.crownGold
        title.verticalAlignmentMode = .center
        title.horizontalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: 16)
        banner.addChild(title)

        let subtitle = SKLabelNode(fontNamed: Theme.bodyFont)
        subtitle.text = "LEVEL \(level)"
        subtitle.fontSize = 26
        subtitle.fontColor = Theme.primaryText
        subtitle.verticalAlignmentMode = .center
        subtitle.horizontalAlignmentMode = .center
        subtitle.position = CGPoint(x: 0, y: -22)
        banner.addChild(subtitle)

        banner.run(.sequence([
            .group([
                .fadeIn(withDuration: 0.16),
                .sequence([
                    .scale(to: 1.18, duration: 0.22),
                    .scale(to: 1.0, duration: 0.12)
                ])
            ]),
            .wait(forDuration: 0.90),
            .group([
                .fadeOut(withDuration: 0.34),
                .moveBy(x: 0, y: 34, duration: 0.34),
                .scale(to: 0.9, duration: 0.34)
            ]),
            .removeFromParent()
        ]))
    }

    /// A full-screen wash used to hide the moment the skin swaps.
    static func skinChangeFlash(size: CGSize, in parent: SKNode, onPeak: @escaping () -> Void) {
        let flash = SKSpriteNode(color: .white, size: size)
        flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        flash.zPosition = Theme.Layer.effects + 20
        flash.alpha = 0
        flash.blendMode = .add
        parent.addChild(flash)

        flash.run(.sequence([
            .fadeAlpha(to: 0.55, duration: 0.16),
            .run(onPeak),
            .fadeOut(withDuration: 0.42),
            .removeFromParent()
        ]))
    }
}
