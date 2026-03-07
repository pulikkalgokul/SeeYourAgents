import SpriteKit
import AppKit

final class AssetLoader {
    static let shared = AssetLoader()

    // Wall sprites: 16 textures indexed by bitmask
    private(set) var wallTextures: [SKTexture] = []
    private(set) var wallImages: [CGImage] = []

    // Floor sprites: up to 7 textures
    private(set) var floorTextures: [SKTexture] = []
    private(set) var floorImages: [CGImage] = []

    // Furniture sprites keyed by asset ID
    private(set) var furnitureTextures: [String: SKTexture] = [:]
    private(set) var furnitureImages: [String: CGImage] = [:]

    private(set) var isLoaded = false

    private init() {}

    func loadAllAssets() {
        guard !isLoaded else { return }
        loadWallSprites()
        loadFloorSprites()
        loadFurnitureSprites()
        isLoaded = true
        print("[AssetLoader] Assets loaded: \(wallTextures.count) walls, \(floorTextures.count) floors, \(furnitureTextures.count) furniture")
    }

    // MARK: - Wall sprites

    private func loadWallSprites() {
        guard let url = Bundle.main.url(forResource: "walls", withExtension: "png"),
              let nsImage = NSImage(contentsOf: url),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("[AssetLoader] walls.png not found, wall sprites unavailable")
            return
        }

        let pieceW = OfficeConstants.wallPieceWidth
        let pieceH = OfficeConstants.wallPieceHeight
        let cols = OfficeConstants.wallGridCols

        for index in 0..<OfficeConstants.wallBitmaskCount {
            let col = index % cols
            let row = index / cols
            let rect = CGRect(x: col * pieceW, y: row * pieceH, width: pieceW, height: pieceH)

            if let cropped = cgImage.cropping(to: rect) {
                wallImages.append(cropped)
                let texture = SKTexture(cgImage: cropped)
                texture.filteringMode = .nearest
                wallTextures.append(texture)
            }
        }
    }

    // MARK: - Floor sprites

    private func loadFloorSprites() {
        if let url = Bundle.main.url(forResource: "floors", withExtension: "png"),
           let nsImage = NSImage(contentsOf: url),
           let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let tileSize = Int(OfficeConstants.tileSize)
            let count = cgImage.width / tileSize

            for i in 0..<count {
                let rect = CGRect(x: i * tileSize, y: 0, width: tileSize, height: tileSize)
                if let cropped = cgImage.cropping(to: rect) {
                    floorImages.append(cropped)
                    let texture = SKTexture(cgImage: cropped)
                    texture.filteringMode = .nearest
                    floorTextures.append(texture)
                }
            }
        }

        // Fallback: generate solid gray tiles if no floors.png
        if floorImages.isEmpty {
            if let grayImage = createSolidColorImage(
                width: Int(OfficeConstants.tileSize),
                height: Int(OfficeConstants.tileSize),
                color: NSColor(white: OfficeConstants.fallbackFloorGray, alpha: 1)
            ) {
                floorImages.append(grayImage)
                let texture = SKTexture(cgImage: grayImage)
                texture.filteringMode = .nearest
                floorTextures.append(texture)
            }
        }
    }

    // MARK: - Furniture sprites

    private func loadFurnitureSprites() {
        guard let url = Bundle.main.url(forResource: "furniture-catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode([FurnitureCatalogJSON].self, from: data) else {
            return
        }

        for item in catalog {
            if let pngURL = Bundle.main.url(forResource: item.id, withExtension: "png"),
               let nsImage = NSImage(contentsOf: pngURL),
               let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                furnitureImages[item.id] = cgImage
                let texture = SKTexture(cgImage: cgImage)
                texture.filteringMode = .nearest
                furnitureTextures[item.id] = texture
            }
        }
    }

    // MARK: - Helpers

    func floorImage(forPattern index: Int) -> CGImage? {
        let idx = index - 1
        if idx >= 0 && idx < floorImages.count {
            return floorImages[idx]
        }
        return floorImages.first
    }

    func floorTexture(forPattern index: Int) -> SKTexture? {
        let idx = index - 1
        if idx >= 0 && idx < floorTextures.count {
            return floorTextures[idx]
        }
        return floorTextures.first
    }

    private func createSolidColorImage(width: Int, height: Int, color: NSColor) -> CGImage? {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        guard let ctx = context else { return nil }
        ctx.setFillColor(color.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }
}
