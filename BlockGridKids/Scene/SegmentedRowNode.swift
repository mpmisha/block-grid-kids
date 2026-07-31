import SpriteKit

/// A labelled row of mutually exclusive options, used to pick the board size.
final class SegmentedRowNode: SKNode {

    private let rowSize: CGSize
    private let action: (Int) -> Void
    private let values: [Int]
    private var segments: [SKShapeNode] = []
    private var labels: [SKLabelNode] = []

    private(set) var selectedValue: Int

    init(title: String,
         values: [Int],
         titles: [String],
         selected: Int,
         width: CGFloat,
         action: @escaping (Int) -> Void) {
        self.values = values
        self.selectedValue = selected
        self.action = action
        self.rowSize = CGSize(width: width, height: 46)
        super.init()

        let label = SKLabelNode(fontNamed: Theme.bodyFont)
        label.text = title
        label.fontSize = 19
        label.fontColor = Theme.primaryText
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .left
        label.position = CGPoint(x: -width / 2, y: 0)
        addChild(label)

        let segmentWidth: CGFloat = 58
        let segmentHeight: CGFloat = 36
        let spacing: CGFloat = 8
        let groupWidth = CGFloat(values.count) * segmentWidth + CGFloat(values.count - 1) * spacing

        for (index, text) in titles.enumerated() {
            let rect = CGRect(x: -segmentWidth / 2, y: -segmentHeight / 2,
                              width: segmentWidth, height: segmentHeight)
            let segment = SKShapeNode(path: CGPath(
                roundedRect: rect,
                cornerWidth: 12, cornerHeight: 12,
                transform: nil
            ))
            segment.strokeColor = .clear
            segment.position = CGPoint(
                x: width / 2 - groupWidth + segmentWidth / 2
                    + CGFloat(index) * (segmentWidth + spacing),
                y: 0
            )
            addChild(segment)
            segments.append(segment)

            let caption = SKLabelNode(fontNamed: Theme.bodyFont)
            caption.text = text
            caption.fontSize = 16
            caption.verticalAlignmentMode = .center
            caption.horizontalAlignmentMode = .center
            caption.zPosition = 1
            segment.addChild(caption)
            labels.append(caption)
        }

        applySelection(animated: false)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// `point` is expressed in scene coordinates. Returns the value whose
    /// segment was hit, or `nil` when the touch missed every segment.
    func value(at point: CGPoint) -> Int? {
        guard let scene else { return nil }
        let local = convert(point, from: scene)
        for (index, segment) in segments.enumerated() {
            let rect = segment.frame.insetBy(dx: -6, dy: -6)
            if rect.contains(local) {
                return values[index]
            }
        }
        return nil
    }

    /// True when the touch landed anywhere on this row's segments.
    func containsTouch(_ point: CGPoint) -> Bool {
        value(at: point) != nil
    }

    func select(_ value: Int, notify: Bool) {
        guard values.contains(value) else { return }
        let didChange = value != selectedValue
        selectedValue = value
        applySelection(animated: true)
        SoundPlayer.shared.play(.button)
        if notify && didChange {
            action(value)
        }
    }

    private func applySelection(animated: Bool) {
        for (index, segment) in segments.enumerated() {
            let isSelected = values[index] == selectedValue
            segment.fillColor = isSelected ? Theme.toggleOn : Theme.toggleOff
            labels[index].fontColor = isSelected ? .white : Theme.secondaryText

            if animated {
                segment.removeAllActions()
                segment.run(.sequence([
                    .scale(to: isSelected ? 1.10 : 0.96, duration: 0.09),
                    .scale(to: 1.0, duration: 0.09)
                ]))
            }
        }
    }
}
