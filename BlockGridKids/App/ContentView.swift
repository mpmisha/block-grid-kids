import SpriteKit
import SwiftUI

/// Keeps one long-lived `GameScene` alive across SwiftUI body evaluations so
/// the game is never rebuilt (and never resets) on a layout pass.
final class SceneHost: ObservableObject {

    private let gameScene: GameScene

    init() {
        gameScene = GameScene()
        gameScene.scaleMode = .resizeFill
    }

    func scene(sized size: CGSize) -> GameScene {
        if size.width > 0, size.height > 0, gameScene.size != size {
            gameScene.size = size
        }
        return gameScene
    }
}

/// A full-screen host for the SpriteKit game. This is the entire UIKit/SwiftUI
/// surface of the app; everything else is drawn by the scene.
struct ContentView: View {

    @StateObject private var host = SceneHost()

    var body: some View {
        GeometryReader { geometry in
            SpriteView(
                scene: host.scene(sized: geometry.size),
                preferredFramesPerSecond: 60,
                options: [.ignoresSiblingOrder]
            )
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .background(Color(Theme.backgroundBottom))
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }
}
