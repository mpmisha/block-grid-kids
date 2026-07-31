import SpriteKit

/// The gradient backdrop plus a few slow-drifting bubbles, which give the
/// screen a soft, playful feel without distracting from the board.
final class BackgroundNode: SKNode {

    private var gradient: SKSpriteNode?
    private let bubbleLayer = SKNode()
    private var lastLaidOutSize: CGSize = .zero

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
        lastLaidOutSize = size
        gradient?.removeFromParent()

        let sprite = SKSpriteNode(texture: BackgroundNode.makeGradientTexture(size: size))
        sprite.size = size
        sprite.position = CGPoint(x: size.width / 2, y: size.height / 2)
        sprite.zPosition = Theme.Layer.background
        addChild(sprite)
        gradient = sprite

        buildBubbles(in: size)
    }

    /// Repaints the gradient and its pattern for the skin that is now active.
    /// The drifting bubbles are left alone so the motion stays continuous
    /// across a level change.
    func applySkin() {
        guard lastLaidOutSize.width > 0, lastLaidOutSize.height > 0 else { return }
        gradient?.texture = BackgroundNode.makeGradientTexture(size: lastLaidOutSize)
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
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0, 1]
            ) {
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: 0, y: canvas.height),
                    options: []
                )
            } else {
                Theme.backgroundTop.setFill()
                context.fill(CGRect(origin: .zero, size: canvas))
            }

            drawPattern(SkinCatalog.surfaceStyle, in: context.cgContext, canvas: canvas)
        }
        return SKTexture(image: image)
    }

    /// The skin's pattern, painted straight into the gradient so it costs no
    /// extra nodes and no extra draw calls.
    private static func drawPattern(_ style: SurfaceStyle,
                                    in context: CGContext,
                                    canvas: CGSize) {
        let tint = SkinCatalog.surfacePalette.pattern
        context.setFillColor(tint.cgColor)
        context.setStrokeColor(tint.cgColor)

        switch style {
        case .plain:
            break

        case .dots:
            let spacing: CGFloat = 46
            let radius: CGFloat = 5
            var row = 0
            var y: CGFloat = spacing / 2
            while y < canvas.height + spacing {
                let offset: CGFloat = row % 2 == 0 ? 0 : spacing / 2
                var x: CGFloat = spacing / 2 + offset
                while x < canvas.width + spacing {
                    context.fillEllipse(in: CGRect(x: x - radius, y: y - radius,
                                                   width: radius * 2, height: radius * 2))
                    x += spacing
                }
                y += spacing
                row += 1
            }

        case .stripes:
            context.saveGState()
            context.translateBy(x: canvas.width / 2, y: canvas.height / 2)
            context.rotate(by: -.pi / 4)
            let reach = max(canvas.width, canvas.height) * 1.5
            let width: CGFloat = 22
            var offset = -reach
            while offset < reach {
                context.fill(CGRect(x: offset, y: -reach, width: width, height: reach * 2))
                offset += width * 2.6
            }
            context.restoreGState()

        case .waves:
            context.setLineWidth(3)
            let amplitude: CGFloat = 14
            let wavelength: CGFloat = 120
            var y: CGFloat = 40
            while y < canvas.height + amplitude {
                let path = UIBezierPath()
                path.move(to: CGPoint(x: -wavelength, y: y))
                var x: CGFloat = -wavelength
                while x < canvas.width + wavelength {
                    path.addCurve(
                        to: CGPoint(x: x + wavelength, y: y),
                        controlPoint1: CGPoint(x: x + wavelength * 0.25, y: y - amplitude),
                        controlPoint2: CGPoint(x: x + wavelength * 0.75, y: y + amplitude)
                    )
                    x += wavelength
                }
                path.stroke()
                y += 58
            }
        }
    }
}
