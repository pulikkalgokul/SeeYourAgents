import SwiftUI
import SpriteKit

struct OfficeView: NSViewRepresentable {
    let scene: OfficeScene = {
        let scene = OfficeScene(size: CGSize(width: 800, height: 600))
        scene.scaleMode = .resizeFill
        return scene
    }()

    func makeNSView(context: Context) -> SKView {
        let skView = SKView()
        skView.ignoresSiblingOrder = false
        skView.presentScene(scene)
        return skView
    }

    func updateNSView(_ nsView: SKView, context: Context) {}
}
