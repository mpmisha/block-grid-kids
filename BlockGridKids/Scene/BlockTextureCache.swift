import SpriteKit
import UIKit

/// Renders and caches the block artwork for the active skin.
///
/// Every block is drawn once per color per cell size into a texture, so the
/// scene can use cheap `SKSpriteNode`s instead of hundreds of shape nodes.
/// The cache is thrown away whenever the layout changes the cell size or the
/// player earns a new skin.
final class BlockTextureCache {

    static let shared = BlockTextureCache()

    private var filledTextures: [Int: SKTexture] = [:]
    private var emptyTexture: SKTexture?
    private var cachedSide: CGFloat = 0
    private var cachedSkinRevision = -1

    private init() {}

    /// Invalidates the cache when the layout changes the cell size.
    func prepare(cellSide: CGFloat) {
        let rounded = (cellSide * 2).rounded() / 2
        guard rounded != cachedSide else { return }
        cachedSide = rounded
        flush()
    }

    /// Drops every cached texture so the next request repaints with the
    /// current skin. Call after `SkinCatalog.apply`.
    func invalidateForSkinChange() {
        flush()
    }

    private func flush() {
        filledTextures.removeAll()
        emptyTexture = nil
        cachedSkinRevision = SkinCatalog.revision
    }

    /// Catches the case where the skin changed without anyone telling us.
    private func flushIfSkinChanged() {
        guard cachedSkinRevision != SkinCatalog.revision else { return }
        flush()
    }

    func filledTexture(colorIndex: Int) -> SKTexture {
        flushIfSkinChanged()
        if let cached = filledTextures[colorIndex] {
            return cached
        }
        let texture = BlockTextureCache.makeFilledTexture(
            color: Theme.blockColor(colorIndex),
            side: max(1, cachedSide),
            style: SkinCatalog.blockStyle
        )
        filledTextures[colorIndex] = texture
        return texture
    }

    func emptyCellTexture() -> SKTexture {
        flushIfSkinChanged()
        if let cached = emptyTexture {
            return cached
        }
        let texture = BlockTextureCache.makeEmptyTexture(
            side: max(1, cachedSide),
            style: SkinCatalog.surfaceStyle
        )
        emptyTexture = texture
        return texture
    }

    // MARK: - Drawing

    private static func renderer(side: CGFloat) -> UIGraphicsImageRenderer {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = UIScreen.main.scale
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
    }

    private static func makeFilledTexture(color: UIColor,
                                          side: CGFloat,
                                          style: BlockStyle) -> SKTexture {
        let image = renderer(side: side).image { context in
            let cgContext = context.cgContext

            // Outer body: a darker version of the color forms the bevel edge.
            // It fills the whole cell so adjacent blocks in a shape touch.
            let bodyInset = side * 0.012
            let bodyRect = CGRect(x: bodyInset, y: bodyInset,
                                  width: side - bodyInset * 2,
                                  height: side - bodyInset * 2)
            let bodyRadius = side * Theme.blockCornerRadiusRatio
            let bodyPath = UIBezierPath(roundedRect: bodyRect, cornerRadius: bodyRadius)
            cgContext.setFillColor(color.adjustingBrightness(by: style.bodyDarkening).cgColor)
            bodyPath.fill()

            // Raised face, nudged up so the bottom edge reads as a shadow.
            let faceInset = side * 0.13
            let faceRect = CGRect(x: faceInset,
                                  y: faceInset * 0.70,
                                  width: side - faceInset * 2,
                                  height: side - faceInset * 2.25)
            let facePath = UIBezierPath(roundedRect: faceRect,
                                        cornerRadius: bodyRadius * style.faceRadiusScale)
            cgContext.setFillColor(color.cgColor)
            facePath.fill()

            cgContext.saveGState()
            facePath.addClip()
            switch style {
            case .candy: drawCandyFace(in: cgContext, face: faceRect, side: side)
            case .brick: drawBrickFace(in: cgContext, face: faceRect, side: side, color: color)
            case .liquid: drawLiquidFace(in: cgContext, face: faceRect, color: color)
            case .metal: drawMetalFace(in: cgContext, face: faceRect, side: side, color: color)
            }
            cgContext.restoreGState()
        }

        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }

    // MARK: - Face styles

    /// Glossy top half plus a bright corner spark: the original candy look.
    private static func drawCandyFace(in context: CGContext, face: CGRect, side: CGFloat) {
        context.setFillColor(UIColor(white: 1, alpha: 0.22).cgColor)
        context.fill(CGRect(x: face.minX, y: face.minY,
                            width: face.width, height: face.height * 0.42))

        let highlightSide = side * 0.16
        let highlightRect = CGRect(x: face.minX + side * 0.06,
                                   y: face.minY + side * 0.06,
                                   width: highlightSide,
                                   height: highlightSide * 0.6)
        context.setFillColor(UIColor(white: 1, alpha: 0.45).cgColor)
        UIBezierPath(roundedRect: highlightRect, cornerRadius: highlightSide * 0.3).fill()
    }

    /// Three courses of bricks with offset vertical joints.
    private static func drawBrickFace(in context: CGContext,
                                      face: CGRect,
                                      side: CGFloat,
                                      color: UIColor) {
        let courses = 3
        let courseHeight = face.height / CGFloat(courses)
        let joint = max(1, side * 0.035)

        context.setFillColor(UIColor(white: 1, alpha: 0.14).cgColor)
        context.fill(CGRect(x: face.minX, y: face.minY,
                            width: face.width, height: courseHeight * 0.5))

        context.setFillColor(color.adjustingBrightness(by: 0.58).cgColor)
        for index in 1..<courses {
            let y = face.minY + courseHeight * CGFloat(index)
            context.fill(CGRect(x: face.minX, y: y - joint / 2, width: face.width, height: joint))
        }

        for index in 0..<courses {
            let y = face.minY + courseHeight * CGFloat(index)
            // Alternate courses are offset by half a brick, like real masonry.
            let x = index % 2 == 0 ? face.midX : face.minX + face.width * 0.22
            context.fill(CGRect(x: x - joint / 2, y: y, width: joint, height: courseHeight))
            if index % 2 != 0 {
                context.fill(CGRect(x: face.minX + face.width * 0.78 - joint / 2,
                                    y: y, width: joint, height: courseHeight))
            }
        }

        // A touch of shadow along the bottom grounds the whole block.
        context.setFillColor(color.adjustingBrightness(by: 0.80).cgColor)
        context.fill(CGRect(x: face.minX, y: face.maxY - side * 0.05,
                            width: face.width, height: side * 0.05))
    }

    /// A wet bead: bright caustic near the top, deeper tone at the bottom.
    private static func drawLiquidFace(in context: CGContext, face: CGRect, color: UIColor) {
        let space = CGColorSpaceCreateDeviceRGB()
        let shades = [
            color.lightened(0.42).cgColor,
            color.cgColor,
            color.adjustingBrightness(by: 0.74).cgColor
        ] as CFArray
        if let gradient = CGGradient(colorsSpace: space, colors: shades,
                                     locations: [0, 0.55, 1]) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: face.midX, y: face.minY),
                end: CGPoint(x: face.midX, y: face.maxY),
                options: []
            )
        }

        // Big soft caustic blob near the top-left.
        let blob = CGRect(x: face.minX + face.width * 0.12,
                          y: face.minY + face.height * 0.10,
                          width: face.width * 0.46,
                          height: face.height * 0.30)
        context.setFillColor(UIColor(white: 1, alpha: 0.50).cgColor)
        UIBezierPath(ovalIn: blob).fill()

        // Small trailing droplet highlight.
        let droplet = CGRect(x: face.minX + face.width * 0.64,
                             y: face.minY + face.height * 0.24,
                             width: face.width * 0.16,
                             height: face.height * 0.13)
        context.setFillColor(UIColor(white: 1, alpha: 0.34).cgColor)
        UIBezierPath(ovalIn: droplet).fill()

        // Bright rim along the bottom, like light through water.
        context.setFillColor(UIColor(white: 1, alpha: 0.16).cgColor)
        context.fill(CGRect(x: face.minX, y: face.maxY - face.height * 0.12,
                            width: face.width, height: face.height * 0.12))
    }

    /// Brushed metal: vertical sheen crossed by a bright diagonal streak.
    private static func drawMetalFace(in context: CGContext,
                                      face: CGRect,
                                      side: CGFloat,
                                      color: UIColor) {
        let space = CGColorSpaceCreateDeviceRGB()
        let shades = [
            color.adjustingBrightness(by: 0.78).cgColor,
            color.lightened(0.34).cgColor,
            color.adjustingBrightness(by: 0.70).cgColor,
            color.lightened(0.12).cgColor
        ] as CFArray
        if let gradient = CGGradient(colorsSpace: space, colors: shades,
                                     locations: [0, 0.34, 0.62, 1]) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: face.midX, y: face.minY),
                end: CGPoint(x: face.midX, y: face.maxY),
                options: []
            )
        }

        // Fine brushed lines.
        context.setFillColor(UIColor(white: 1, alpha: 0.07).cgColor)
        var y = face.minY
        let step = max(2, side * 0.07)
        while y < face.maxY {
            context.fill(CGRect(x: face.minX, y: y,
                                width: face.width, height: max(0.5, step * 0.18)))
            y += step
        }

        // Diagonal specular streak.
        let streak = UIBezierPath()
        streak.move(to: CGPoint(x: face.minX, y: face.maxY - face.height * 0.18))
        streak.addLine(to: CGPoint(x: face.minX + face.width * 0.42, y: face.minY))
        streak.addLine(to: CGPoint(x: face.minX + face.width * 0.66, y: face.minY))
        streak.addLine(to: CGPoint(x: face.minX, y: face.maxY))
        streak.close()
        context.setFillColor(UIColor(white: 1, alpha: 0.26).cgColor)
        streak.fill()
    }

    // MARK: - Empty cell

    private static func makeEmptyTexture(side: CGFloat, style: SurfaceStyle) -> SKTexture {
        let image = renderer(side: side).image { context in
            let cgContext = context.cgContext
            let inset = side * 0.025
            let rect = CGRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
            let path = UIBezierPath(roundedRect: rect,
                                    cornerRadius: side * Theme.blockCornerRadiusRatio)
            cgContext.setFillColor(Theme.emptyCell.cgColor)
            path.fill()

            cgContext.saveGState()
            path.addClip()
            let mark = UIColor(white: 1, alpha: 0.06).cgColor
            switch style {
            case .plain:
                break
            case .dots:
                cgContext.setFillColor(mark)
                let radius = side * 0.10
                cgContext.fillEllipse(in: CGRect(x: rect.midX - radius, y: rect.midY - radius,
                                                 width: radius * 2, height: radius * 2))
            case .stripes:
                cgContext.setFillColor(mark)
                cgContext.translateBy(x: rect.midX, y: rect.midY)
                cgContext.rotate(by: -.pi / 4)
                let width = side * 0.12
                for offset in stride(from: -side, through: side, by: side * 0.34) {
                    cgContext.fill(CGRect(x: offset, y: -side, width: width, height: side * 2))
                }
            case .waves:
                cgContext.setStrokeColor(mark)
                cgContext.setLineWidth(max(1, side * 0.05))
                let wave = UIBezierPath()
                wave.move(to: CGPoint(x: rect.minX, y: rect.midY))
                wave.addCurve(
                    to: CGPoint(x: rect.maxX, y: rect.midY),
                    controlPoint1: CGPoint(x: rect.minX + rect.width * 0.3,
                                           y: rect.midY - rect.height * 0.22),
                    controlPoint2: CGPoint(x: rect.maxX - rect.width * 0.3,
                                           y: rect.midY + rect.height * 0.22)
                )
                wave.stroke()
            }
            cgContext.restoreGState()

            cgContext.setStrokeColor(Theme.emptyCellStroke.cgColor)
            path.lineWidth = max(1, side * 0.02)
            path.stroke()
        }

        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }
}

private extension BlockStyle {
    /// How much darker the bevel body is than the face.
    var bodyDarkening: CGFloat {
        switch self {
        case .candy: return 0.62
        case .brick: return 0.55
        case .liquid: return 0.66
        case .metal: return 0.58
        }
    }

    /// Metal reads as machined, liquid as a bead, so their corners differ.
    var faceRadiusScale: CGFloat {
        switch self {
        case .candy: return 0.60
        case .brick: return 0.35
        case .liquid: return 0.95
        case .metal: return 0.30
        }
    }
}
