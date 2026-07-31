import SpriteKit

/// The gradient backdrop plus a few slow-drifting bubbles, which give the
/// screen a soft, playful feel without distracting from the board.
final class BackgroundNode: SKNode {

    private var gradient: SKSpriteNode?
    private let bubbleLayer = SKNode()

    override init() {
        super.init()
        zPosition = Theme.Layer.background
        bubbleLayer.zPosition = Theme.Layer.bubbles
        addChild(bubbleLayer)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func layout(size: CGSize) {
        gradient?.removeFromParent()

        let sprite = SKSpriteNode(texture: BackgroundNode.makeGradientTexture(size: size))
        sprite.size = size
        sprite.position = CGPoint(x: size.width / 2, y: size.height / 2)
        sprite.zPosition = Theme.Layer.background
        addChild(sprite)
        gradient = sprite

        buildBubbles(in: size)
    }

    private func buildBubbles(in size: CGSize) {
        bubbleLayer.removeAllChildren()

        for index in 0..<9 {
            let radius = CGFloat.random(in: 16...48)
            let bubble = SKShapeNode(circleOfRadius: radius)
            bubble.fillColor = UIColor(white: 1, alpha: CGFloat.random(in: 0.04...0.09))
            bubble.strokeColor = UIColor(white: 1, alpha: 0.06)
            bubble.lineWidth = 1
            bubble.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )
            bubbleLayer.addChild(bubble)

            let drift = CGFloat.random(in: 18...40)
            let duration = TimeInterval.random(in: 6...11)
            bubble.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: drift, duration: duration),
                .moveBy(x: 0, y: -drift, duration: duration)
            ])), withKey: "drift-\(index)")
        }
    }

    private static func makeGradientTexture(size: CGSize) -> SKTexture {
        let canvas = CGSize(width: max(2, size.width), height: max(2, size.height))
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true

        let image = UIGraphicsImageRenderer(size: canvas, format: format).image { context in
            let colors = [Theme.backgroundTop.cgColor, Theme.backgroundBottom.cgColor] as CFArray
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0, 1]
            ) else {
                Theme.backgroundTop.setFill()
                context.fill(CGRect(origin: .zero, size: canvas))
                return
            }
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 0, y: canvas.height),
                options: []
            )
        }
        return SKTexture(image: image)
    }
}
