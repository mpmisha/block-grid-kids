import SpriteKit
import UIKit

/// Renders and caches the beveled block artwork.
///
/// Every block is drawn once per color per cell size into a texture, so the
/// scene can use cheap `SKSpriteNode`s instead of hundreds of shape nodes.
final class BlockTextureCache {

    static let shared = BlockTextureCache()

    private var filledTextures: [Int: SKTexture] = [:]
    private var emptyTexture: SKTexture?
    private var cachedSide: CGFloat = 0

    private init() {}

    /// Invalidates the cache when the layout changes the cell size.
    func prepare(cellSide: CGFloat) {
        let rounded = (cellSide * 2).rounded() / 2
        guard rounded != cachedSide else { return }
        cachedSide = rounded
        filledTextures.removeAll()
        emptyTexture = nil
    }

    func filledTexture(colorIndex: Int) -> SKTexture {
        if let cached = filledTextures[colorIndex] {
            return cached
        }
        let texture = BlockTextureCache.makeFilledTexture(
            color: Theme.blockColor(colorIndex),
            side: max(1, cachedSide)
        )
        filledTextures[colorIndex] = texture
        return texture
    }

    func emptyCellTexture() -> SKTexture {
        if let cached = emptyTexture {
            return cached
        }
        let texture = BlockTextureCache.makeEmptyTexture(side: max(1, cachedSide))
        emptyTexture = texture
        return texture
    }

    // MARK: - Drawing

    private static func makeFilledTexture(color: UIColor, side: CGFloat) -> SKTexture {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = UIScreen.main.scale

        let canvas = CGSize(width: side, height: side)
        let image = UIGraphicsImageRenderer(size: canvas, format: format).image { context in
            let cgContext = context.cgContext

            // Outer body: a darker version of the color forms the bevel edge.
            // It fills the whole cell so adjacent blocks in a shape touch.
            let bodyInset = side * 0.012
            let bodyRect = CGRect(x: bodyInset, y: bodyInset,
                                  width: side - bodyInset * 2,
                                  height: side - bodyInset * 2)
            let bodyRadius = side * Theme.blockCornerRadiusRatio
            let bodyPath = UIBezierPath(roundedRect: bodyRect, cornerRadius: bodyRadius)
            cgContext.setFillColor(color.adjustingBrightness(by: 0.62).cgColor)
            bodyPath.fill()

            // Raised face, nudged up so the bottom edge reads as a shadow.
            let faceInset = side * 0.13
            let faceRect = CGRect(x: faceInset,
                                  y: faceInset * 0.70,
                                  width: side - faceInset * 2,
                                  height: side - faceInset * 2.25)
            let facePath = UIBezierPath(roundedRect: faceRect, cornerRadius: bodyRadius * 0.6)
            cgContext.setFillColor(color.cgColor)
            facePath.fill()

            // Soft gloss across the top of the face.
            cgContext.saveGState()
            facePath.addClip()
            let glossRect = CGRect(x: faceRect.minX,
                                   y: faceRect.minY,
                                   width: faceRect.width,
                                   height: faceRect.height * 0.42)
            cgContext.setFillColor(UIColor(white: 1, alpha: 0.22).cgColor)
            cgContext.fill(glossRect)
            cgContext.restoreGState()

            // Bright corner highlight for the candy look.
            let highlightSide = side * 0.16
            let highlightRect = CGRect(x: faceRect.minX + side * 0.06,
                                       y: faceRect.minY + side * 0.06,
                                       width: highlightSide,
                                       height: highlightSide * 0.6)
            let highlightPath = UIBezierPath(roundedRect: highlightRect,
                                             cornerRadius: highlightSide * 0.3)
            cgContext.setFillColor(UIColor(white: 1, alpha: 0.45).cgColor)
            highlightPath.fill()
        }

        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }

    private static func makeEmptyTexture(side: CGFloat) -> SKTexture {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = UIScreen.main.scale

        let canvas = CGSize(width: side, height: side)
        let image = UIGraphicsImageRenderer(size: canvas, format: format).image { context in
            let inset = side * 0.025
            let rect = CGRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: side * Theme.blockCornerRadiusRatio)
            context.cgContext.setFillColor(Theme.emptyCell.cgColor)
            path.fill()
            context.cgContext.setStrokeColor(Theme.emptyCellStroke.cgColor)
            path.lineWidth = max(1, side * 0.02)
            path.stroke()
        }

        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }
}
