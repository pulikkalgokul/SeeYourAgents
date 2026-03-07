import SpriteKit

final class TextureCache {
    static let shared = TextureCache()

    private let cache = NSCache<NSString, SKTexture>()

    private init() {
        cache.countLimit = 500
    }

    func colorizedTexture(base: CGImage, color: FloorColor, key: String) -> SKTexture {
        let nsKey = key as NSString
        if let cached = cache.object(forKey: nsKey) {
            return cached
        }

        let colorized = colorizeImage(base, color: color)
        let texture: SKTexture
        if let img = colorized {
            texture = SKTexture(cgImage: img)
        } else {
            texture = SKTexture(cgImage: base)
        }
        texture.filteringMode = .nearest
        cache.setObject(texture, forKey: nsKey)
        return texture
    }

    func clear() {
        cache.removeAllObjects()
    }
}
