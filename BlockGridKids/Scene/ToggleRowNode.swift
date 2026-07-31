import SpriteKit

/// A labelled on/off row used in the settings panel.
final class ToggleRowNode: SKNode {

    private let track = SKShapeNode()
    private let knob = SKShapeNode()
    private let label = SKLabelNode(fontNamed: Theme.bodyFont)
    private let rowSize: CGSize
    private let trackSize: CGSize
    private let action: (Bool) -> Void

    private(set) var isOn: Bool

    init(title: String, isOn: Bool, width: CGFloat, action: @escaping (Bool) -> Void) {
        self.isOn = isOn
        self.action = action
        self.rowSize = CGSize(width: width, height: 46)
        self.trackSize = CGSize(width: 62, height: 34)
        super.init()

        label.text = title
        label.fontSize = 19
        label.fontColor = Theme.primaryText
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .left
        label.position = CGPoint(x: -width / 2, y: 0)
        addChild(label)

        let trackRect = CGRect(
            x: -trackSize.width / 2,
            y: -trackSize.height / 2,
            width: trackSize.width,
            height: trackSize.height
        )
        track.path = CGPath(
            roundedRect: trackRect,
            cornerWidth: trackSize.height / 2,
            cornerHeight: trackSize.height / 2,
            transform: nil
        )
        track.strokeColor = .clear
        track.position = CGPoint(x: width / 2 - trackSize.width / 2, y: 0)
        addChild(track)

        knob.path = CGPath(ellipseIn: CGRect(x: -13, y: -13, width: 26, height: 26), transform: nil)
        knob.fillColor = .white
        knob.strokeColor = .clear
        knob.zPosition = 1
        track.addChild(knob)

        applyState(animated: false)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// `point` is expressed in scene coordinates.
    func containsTouch(_ point: CGPoint) -> Bool {
        guard let scene else { return false }
        let local = convert(point, from: scene)
        let rect = CGRect(
            x: -rowSize.width / 2 - 8,
            y: -rowSize.height / 2,
            width: rowSize.width + 16,
            height: rowSize.height
        )
        return rect.contains(local)
    }

    func toggle() {
        isOn.toggle()
        applyState(animated: true)
        // Apply the setting first so switching sound back on is immediately audible.
        action(isOn)
        SoundPlayer.shared.play(.button)
    }

    private func applyState(animated: Bool) {
        let knobX = isOn ? (trackSize.width / 2 - 17) : -(trackSize.width / 2 - 17)
        let fill = isOn ? Theme.toggleOn : Theme.toggleOff

        if animated {
            knob.run(.moveTo(x: knobX, duration: 0.14))
        } else {
            knob.position = CGPoint(x: knobX, y: 0)
        }
        track.fillColor = fill
    }
}
