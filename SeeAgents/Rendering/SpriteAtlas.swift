import Foundation

struct SpriteRegion: Codable {
    let sheet: String
    let x: Int
    let y: Int
    let w: Int
    let h: Int
}

struct SpriteAtlasManifest: Codable {
    let sheets: [String: SheetDef]
    let sprites: [String: SpriteRegion]
    let floors: [SpriteRegion]
    let assetMapping: [String: String]

    struct SheetDef: Codable {
        let file: String
    }
}
