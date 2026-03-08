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
        loadSpriteMappedAssets()
        isLoaded = true
        print("[AssetLoader] Assets loaded: \(wallTextures.count) walls, \(floorTextures.count) floors, \(furnitureTextures.count) furniture")
    }

    // MARK: - Sprite Mapping (individual PNGs)

    private func loadSpriteMappedAssets() {
        guard let url = Bundle.main.url(forResource: "sprite-mapping", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let mapping = try? JSONDecoder().decode(SpriteMapping.self, from: data) else {
            print("[AssetLoader] sprite-mapping.json not found, falling back")
            loadFloorFallback()
            return
        }

        loadFloorSprites(from: mapping)
        loadFurnitureSprites(from: mapping)
    }

    // MARK: - Floor sprites

    private func loadFloorSprites(from mapping: SpriteMapping) {
        for filename in mapping.floors {
            if let cgImage = loadSpriteImage(named: filename) {
                floorImages.append(cgImage)
                let texture = SKTexture(cgImage: cgImage)
                texture.filteringMode = .nearest
                floorTextures.append(texture)
            }
        }

        if floorImages.isEmpty {
            loadFloorFallback()
        }
    }

    private func loadFloorFallback() {
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

    // MARK: - Furniture sprites

    private func loadFurnitureSprites(from mapping: SpriteMapping) {
        for (assetID, filename) in mapping.assets {
            if let cgImage = loadSpriteImage(named: filename) {
                furnitureImages[assetID] = cgImage
                let texture = SKTexture(cgImage: cgImage)
                texture.filteringMode = .nearest
                furnitureTextures[assetID] = texture
            }
        }
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

    // MARK: - Helpers

    private func loadSpriteImage(named filename: String) -> CGImage? {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "png"),
              let nsImage = NSImage(contentsOf: url),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        return cgImage
    }

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
