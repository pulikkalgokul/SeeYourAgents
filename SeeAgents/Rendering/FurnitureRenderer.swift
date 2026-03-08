import SpriteKit

struct FurnitureInstance {
    let node: SKSpriteNode
    let zY: CGFloat
}

enum FurnitureRenderer {

    static func renderFurniture(
        furniture: [PlacedFurniture],
        totalRows: Int
    ) -> [FurnitureInstance] {
        let tileSize = OfficeConstants.tileSize
        let catalog = FurnitureCatalog.shared
        let loader = AssetLoader.shared

        // Pre-compute desk zY per tile for surface items
        var deskZByTile: [String: CGFloat] = [:]
        for item in furniture {
            guard let entry = catalog.entry(for: item.type), entry.isDesk else { continue }
            let deskZY = CGFloat(item.row) * tileSize + CGFloat(entry.spriteHeight)
            for dr in 0..<entry.footprintH {
                for dc in 0..<entry.footprintW {
                    let key = "\(item.col + dc),\(item.row + dr)"
                    if let prev = deskZByTile[key] {
                        if deskZY > prev { deskZByTile[key] = deskZY }
                    } else {
                        deskZByTile[key] = deskZY
                    }
                }
            }
        }

        var instances: [FurnitureInstance] = []

        for item in furniture {
            guard let entry = catalog.entry(for: item.type) else {
                print("[FurnitureRenderer] Unknown furniture type: \(item.type)")
                continue
            }

            let spriteW = CGFloat(entry.spriteWidth)
            let spriteH = CGFloat(entry.spriteHeight)
            var zY = CGFloat(item.row) * tileSize + spriteH

            // Chair z-sorting
            if entry.category == "chairs" {
                if entry.orientation == "back" {
                    zY = CGFloat(item.row + 1) * tileSize + 1
                } else {
                    zY = CGFloat(item.row + 1) * tileSize
                }
            }

            // Surface items render in front of desks
            if entry.canPlaceOnSurfaces {
                for dr in 0..<entry.footprintH {
                    for dc in 0..<entry.footprintW {
                        let key = "\(item.col + dc),\(item.row + dr)"
                        if let deskZ = deskZByTile[key], deskZ + 0.5 > zY {
                            zY = deskZ + 0.5
                        }
                    }
                }
            }

            // Get or create texture
            let texture: SKTexture
            if let furnitureTexture = loader.furnitureTextures[item.type] {
                if let color = item.color, let baseImage = loader.furnitureImages[item.type] {
                    let key = "furn-\(item.type)-\(color.h)-\(color.s)-\(color.b)-\(color.c)-\(color.colorize == true ? 1 : 0)"
                    texture = TextureCache.shared.colorizedTexture(base: baseImage, color: color, key: key)
                } else {
                    texture = furnitureTexture
                }
            } else {
                // Missing tabletop props are less disruptive when hidden than as solid debug blocks.
                if entry.canPlaceOnSurfaces {
                    continue
                }
                // Fallback: colored rectangle placeholder
                let placeholderColor = placeholderColor(for: entry.category)
                let node = SKSpriteNode(color: placeholderColor, size: CGSize(width: spriteW, height: spriteH))
                node.anchorPoint = CGPoint(x: 0, y: 0)
                let bottomY = CGFloat(totalRows - item.row) * tileSize - spriteH
                node.position = CGPoint(x: CGFloat(item.col) * tileSize, y: bottomY)
                node.zPosition = zY
                instances.append(FurnitureInstance(node: node, zY: zY))
                continue
            }

            let node = SKSpriteNode(texture: texture, size: CGSize(width: spriteW, height: spriteH))
            node.anchorPoint = CGPoint(x: 0, y: 0)
            let bottomY = CGFloat(totalRows - item.row) * tileSize - spriteH
            node.position = CGPoint(x: CGFloat(item.col) * tileSize, y: bottomY)
            node.zPosition = zY

            instances.append(FurnitureInstance(node: node, zY: zY))
        }

        return instances
    }

    private static func placeholderColor(for category: String) -> NSColor {
        switch category {
        case "desks": return NSColor(red: 0.55, green: 0.35, blue: 0.2, alpha: 0.8)
        case "chairs": return NSColor(red: 0.3, green: 0.3, blue: 0.6, alpha: 0.8)
        case "storage": return NSColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 0.8)
        case "electronics": return NSColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 0.8)
        case "decor": return NSColor(red: 0.2, green: 0.5, blue: 0.2, alpha: 0.8)
        case "wall": return NSColor(red: 0.4, green: 0.4, blue: 0.5, alpha: 0.7)
        case "misc": return NSColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 0.8)
        default: return NSColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 0.8)
        }
    }
}
