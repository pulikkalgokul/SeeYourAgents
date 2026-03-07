import SwiftUI
import SpriteKit

struct OfficeView: NSViewRepresentable {
    let agentManager: AgentManager

    func makeNSView(context: Context) -> SKView {
        let scene = OfficeScene(size: CGSize(width: 800, height: 600))
        scene.scaleMode = .resizeFill

        let skView = SKView()
        skView.ignoresSiblingOrder = false
        skView.presentScene(scene)

        // Connect agent manager after scene is presented (didMove will have fired)
        DispatchQueue.main.async {
            scene.connectAgentManager(agentManager)
        }

        return skView
    }

    func updateNSView(_ nsView: SKView, context: Context) {}
}
