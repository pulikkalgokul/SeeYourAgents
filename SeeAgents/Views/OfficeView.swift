import SwiftUI
import SpriteKit
import AppKit

struct OfficeView: NSViewRepresentable {
    let agentManager: AgentManager

    func makeNSView(context: Context) -> SKView {
        let scene = OfficeScene(size: CGSize(width: 800, height: 600))
        scene.scaleMode = .resizeFill

        let skView = OfficeSKView()
        skView.ignoresSiblingOrder = false
        skView.officeScene = scene
        skView.presentScene(scene)

        scene.connectAgentManager(agentManager)

        return skView
    }

    func updateNSView(_ nsView: SKView, context: Context) {}
}

final class OfficeSKView: SKView {
    weak var officeScene: OfficeScene?

    private lazy var magnificationRecognizer = NSMagnificationGestureRecognizer(
        target: self,
        action: #selector(handleMagnification(_:))
    )

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addGestureRecognizer(magnificationRecognizer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addGestureRecognizer(magnificationRecognizer)
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func scrollWheel(with event: NSEvent) {
        let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.deltaY
        if officeScene?.handleScroll(delta: delta) == true {
            return
        }
        super.scrollWheel(with: event)
    }

    @objc
    private func handleMagnification(_ recognizer: NSMagnificationGestureRecognizer) {
        officeScene?.handleMagnification(recognizer.magnification)
        recognizer.magnification = 0
    }
}
