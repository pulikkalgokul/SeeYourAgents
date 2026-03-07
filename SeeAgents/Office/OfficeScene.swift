import SpriteKit

final class OfficeScene: SKScene {

    private let floorLayer = SKNode()
    private let entityLayer = SKNode()
    private let characterLayer = SKNode()
    private let cameraNode = SKCameraNode()

    private var currentZoom: CGFloat = OfficeConstants.zoomDefault
    private var isPanning = false
    private var lastPanPoint: CGPoint = .zero

    private(set) var officeState: OfficeState?
    private var agentBridge: AgentBridge?
    private var lastUpdateTime: TimeInterval = 0
    private var loadedLayout: OfficeLayout?

    override func didMove(to view: SKView) {
        backgroundColor = .black
        view.ignoresSiblingOrder = false

        addChild(floorLayer)
        addChild(entityLayer)
        addChild(characterLayer)

        cameraNode.name = "camera"
        addChild(cameraNode)
        camera = cameraNode

        AssetLoader.shared.loadAllAssets()
        CharacterSpriteLoader.shared.loadAllPalettes()
        buildScene()
        applyZoom(currentZoom)
    }

    // MARK: - Agent Manager Connection

    func connectAgentManager(_ agentManager: AgentManager) {
        guard let state = officeState else { return }
        agentBridge = AgentBridge(agentManager: agentManager, officeState: state)
    }

    // MARK: - Game Loop

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
            return
        }

        var dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        dt = min(dt, CharacterConstants.maxDeltaTime)

        agentBridge?.sync()
        officeState?.update(dt: dt)
        updateCharacterNodes()
    }

    private func updateCharacterNodes() {
        guard let state = officeState, let layout = loadedLayout else { return }

        let tileSize = OfficeConstants.tileSize
        let totalRows = CGFloat(layout.rows)

        for ch in state.characters.values {
            // Add to scene if needed
            if ch.spriteNode.parent == nil {
                characterLayer.addChild(ch.spriteNode)
            }

            // Update texture
            if let sprites = CharacterSpriteLoader.shared.sprites(
                forPalette: ch.palette, hueShift: ch.hueShift
            ) {
                let texture = CharacterFSM.getCharacterTexture(ch, sprites: sprites)
                ch.spriteNode.texture = texture
                ch.spriteNode.size = texture.size()
            }

            // Position: convert tile-space Y-down to SpriteKit Y-up
            let spriteX = ch.x
            var spriteY = totalRows * tileSize - ch.y

            // Sitting offset: shift down when typing (sitting in chair)
            if ch.state == .typing {
                spriteY -= CharacterConstants.sittingOffsetPx
            }

            ch.spriteNode.position = CGPoint(x: spriteX, y: spriteY)

            // Z-position: use tile-space Y for depth sorting (higher Y = further back = lower z)
            ch.spriteNode.zPosition = ch.y + tileSize / 2 + CharacterConstants.zSortOffset

            // Flip for left direction
            ch.spriteNode.xScale = ch.dir == .left ? -1 : 1

            // Update bubble
            updateBubble(for: ch, spriteY: spriteY)
        }
    }

    private func updateBubble(for ch: OfficeCharacter, spriteY: CGFloat) {
        if let bubbleType = ch.bubbleType {
            if ch.bubbleNode == nil {
                let label = SKLabelNode(fontNamed: "Menlo")
                label.fontSize = 10
                label.verticalAlignmentMode = .bottom
                ch.bubbleNode = label
                characterLayer.addChild(label)
            }

            if let label = ch.bubbleNode {
                switch bubbleType {
                case .permission:
                    label.text = "..."
                    label.fontColor = .orange
                case .waiting:
                    label.text = "\u{2713}"
                    label.fontColor = .green
                }
                label.position = CGPoint(x: ch.spriteNode.position.x, y: spriteY + CharacterConstants.spriteBodyHeight + 4)
                label.zPosition = ch.spriteNode.zPosition + 1
            }
        } else {
            ch.bubbleNode?.removeFromParent()
            ch.bubbleNode = nil
        }
    }

    // MARK: - Scene Building

    private func buildScene() {
        floorLayer.removeAllChildren()
        entityLayer.removeAllChildren()
        characterLayer.removeAllChildren()

        guard let layout = loadLayout() else {
            print("[OfficeScene] Failed to load layout")
            return
        }

        self.loadedLayout = layout
        print("[OfficeScene] Layout loaded: \(layout.cols)x\(layout.rows), \(layout.tiles.count) tiles, \(layout.furniture.count) furniture")

        let tileMap = layoutToTileMap(layout)
        let totalRows = layout.rows

        // Render floors
        FloorRenderer.renderFloors(tileMap: tileMap, layout: layout, parent: floorLayer)

        // Render walls (z-sorted with furniture)
        let wallInstances = WallRenderer.renderWalls(tileMap: tileMap, layout: layout, totalRows: totalRows)

        // Render furniture (z-sorted)
        let furnitureInstances = FurnitureRenderer.renderFurniture(furniture: layout.furniture, totalRows: totalRows)

        // Add all wall and furniture nodes to entity layer — zPosition handles draw order
        for wall in wallInstances {
            entityLayer.addChild(wall.node)
        }
        for furn in furnitureInstances {
            entityLayer.addChild(furn.node)
        }

        centerCamera(layout: layout)

        // Create OfficeState from layout
        officeState = OfficeState(layout: layout)
    }

    private func loadLayout() -> OfficeLayout? {
        guard let url = Bundle.main.url(forResource: "default-layout", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }

        var layout = try? JSONDecoder().decode(OfficeLayout.self, from: data)

        // Ensure tileColors exists (migration)
        if layout != nil && layout!.tileColors == nil {
            layout!.tileColors = layout!.tiles.map { raw in
                switch raw {
                case 0: return nil // wall
                case 1: return FloorColor(h: 35, s: 30, b: 15, c: 0)
                case 2: return FloorColor(h: 25, s: 45, b: 5, c: 10)
                case 3: return FloorColor(h: 280, s: 40, b: -5, c: 0)
                case 4: return FloorColor(h: 35, s: 25, b: 10, c: 0)
                default: return raw > 0 ? FloorColor(h: 0, s: 0, b: 0, c: 0) : nil
                }
            }
        }

        return layout
    }

    private func centerCamera(layout: OfficeLayout) {
        let tileSize = OfficeConstants.tileSize
        let centerX = CGFloat(layout.cols) * tileSize / 2
        let centerY = CGFloat(layout.rows) * tileSize / 2
        cameraNode.position = CGPoint(x: centerX, y: centerY)
    }

    // MARK: - Zoom

    private func applyZoom(_ zoom: CGFloat) {
        currentZoom = max(OfficeConstants.zoomMin, min(OfficeConstants.zoomMax, zoom))
        cameraNode.setScale(1 / currentZoom)
    }

    override func scrollWheel(with event: NSEvent) {
        let delta = event.deltaY
        if abs(delta) > 0.1 {
            let step: CGFloat = delta > 0 ? 1 : -1
            applyZoom(currentZoom + step)
        }
    }

    // MARK: - Pan (uses window coordinates to avoid scene-coordinate drift)

    override func mouseDown(with event: NSEvent) {
        isPanning = true
        lastPanPoint = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard isPanning else { return }
        let currentPoint = event.locationInWindow
        let dx = currentPoint.x - lastPanPoint.x
        let dy = currentPoint.y - lastPanPoint.y
        // Scale the delta by inverse zoom (camera scale) to get scene-space movement
        let scale = cameraNode.xScale
        cameraNode.position.x -= dx * scale
        cameraNode.position.y -= dy * scale
        lastPanPoint = currentPoint
    }

    override func mouseUp(with event: NSEvent) {
        isPanning = false
    }
}
