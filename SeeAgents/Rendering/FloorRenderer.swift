import SpriteKit

enum FloorRenderer {

    static func renderFloors(
        tileMap: [[TileType]],
        layout: OfficeLayout,
        parent: SKNode
    ) {
        let tileSize = OfficeConstants.tileSize
        let totalRows = tileMap.count

        for row in 0..<tileMap.count {
            for col in 0..<tileMap[row].count {
                let tile = tileMap[row][col]

                if tile == .void_ { continue }

                let position = tilePosition(col: col, row: row, totalRows: totalRows)

                if tile == .wall {
                    // Solid color rectangle for wall base
                    let colorIdx = row * layout.cols + col
                    let wallColor = layout.tileColors?[safe: colorIdx].flatMap({ $0 })

                    let node = SKSpriteNode(color: wallFillColor(wallColor), size: CGSize(width: tileSize, height: tileSize))
                    node.anchorPoint = CGPoint(x: 0, y: 1)
                    node.position = position
                    node.zPosition = 0
                    parent.addChild(node)
                    continue
                }

                if tile.isFloor {
                    let colorIdx = row * layout.cols + col
                    let floorColor = layout.tileColors?[safe: colorIdx].flatMap({ $0 })

                    let texture: SKTexture
                    if let color = floorColor,
                       let baseImage = AssetLoader.shared.floorImage(forPattern: tile.floorPatternIndex) {
                        let colorizeColor = FloorColor(h: color.h, s: color.s, b: color.b, c: color.c, colorize: true)
                        let key = "floor-\(tile.floorPatternIndex)-\(color.h)-\(color.s)-\(color.b)-\(color.c)"
                        texture = TextureCache.shared.colorizedTexture(base: baseImage, color: colorizeColor, key: key)
                    } else if let baseTex = AssetLoader.shared.floorTexture(forPattern: tile.floorPatternIndex) {
                        texture = baseTex
                    } else {
                        continue
                    }

                    let node = SKSpriteNode(texture: texture, size: CGSize(width: tileSize, height: tileSize))
                    node.anchorPoint = CGPoint(x: 0, y: 1)
                    node.position = position
                    node.zPosition = 0
                    parent.addChild(node)
                }
            }
        }
    }

    private static func wallFillColor(_ color: FloorColor?) -> NSColor {
        if let color {
            return wallColorToNSColor(color)
        }
        return NSColor(cgColor: OfficeConstants.wallBaseColor) ?? .darkGray
    }
}

// MARK: - Coordinate transform

func tilePosition(col: Int, row: Int, totalRows: Int) -> CGPoint {
    let tileSize = OfficeConstants.tileSize
    let x = CGFloat(col) * tileSize
    let y = CGFloat(totalRows - row) * tileSize
    return CGPoint(x: x, y: y)
}

// MARK: - Safe array subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

