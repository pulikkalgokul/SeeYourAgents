import SpriteKit

struct WallInstance {
    let node: SKSpriteNode
    let zY: CGFloat
}

enum WallRenderer {

    static func renderWalls(
        tileMap: [[TileType]],
        layout: OfficeLayout,
        totalRows: Int
    ) -> [WallInstance] {
        let loader = AssetLoader.shared
        guard !loader.wallTextures.isEmpty else { return [] }

        let tileSize = OfficeConstants.tileSize
        var instances: [WallInstance] = []

        let tmRows = tileMap.count
        let tmCols = tmRows > 0 ? tileMap[0].count : 0

        for row in 0..<tmRows {
            for col in 0..<tmCols {
                guard tileMap[row][col] == .wall else { continue }

                // Build 4-bit neighbor bitmask: N=1, E=2, S=4, W=8
                var mask = 0
                if row > 0 && tileMap[row - 1][col] == .wall { mask |= 1 }
                if col < tmCols - 1 && tileMap[row][col + 1] == .wall { mask |= 2 }
                if row < tmRows - 1 && tileMap[row + 1][col] == .wall { mask |= 4 }
                if col > 0 && tileMap[row][col - 1] == .wall { mask |= 8 }

                guard mask < loader.wallTextures.count else { continue }

                // Check for tile color
                let colorIdx = row * layout.cols + col
                let wallColor = layout.tileColors?[safe: colorIdx].flatMap({ $0 })

                let texture: SKTexture
                if let color = wallColor, mask < loader.wallImages.count {
                    let colorizeColor = FloorColor(h: color.h, s: color.s, b: color.b, c: color.c, colorize: true)
                    let key = "wall-\(mask)-\(color.h)-\(color.s)-\(color.b)-\(color.c)"
                    texture = TextureCache.shared.colorizedTexture(base: loader.wallImages[mask], color: colorizeColor, key: key)
                } else {
                    texture = loader.wallTextures[mask]
                }

                let spriteHeight = CGFloat(OfficeConstants.wallPieceHeight)
                let node = SKSpriteNode(texture: texture, size: CGSize(width: tileSize, height: spriteHeight))
                node.anchorPoint = CGPoint(x: 0, y: 0) // bottom-left

                // Position: bottom of sprite at bottom of tile row
                let bottomY = CGFloat(totalRows - row - 1) * tileSize
                node.position = CGPoint(x: CGFloat(col) * tileSize, y: bottomY)

                let zY = CGFloat(row + 1) * tileSize
                node.zPosition = zY

                instances.append(WallInstance(node: node, zY: zY))
            }
        }

        return instances
    }
}
