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
}
