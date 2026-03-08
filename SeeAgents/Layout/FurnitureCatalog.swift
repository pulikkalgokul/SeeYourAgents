import Foundation
import CoreGraphics

struct FurnitureCatalogEntry {
    let type: String
    let label: String
    let footprintW: Int
    let footprintH: Int
    let spriteWidth: Int
    let spriteHeight: Int
    let isDesk: Bool
    var category: String = "misc"
    var orientation: String?
    var canPlaceOnSurfaces: Bool = false
    var backgroundTiles: Int = 0
    var canPlaceOnWalls: Bool = false
}

struct FurnitureCatalogJSON: Codable {
    let id: String
    let label: String
    let category: String
    let width: Int
    let height: Int
    let footprintW: Int
    let footprintH: Int
    let isDesk: Bool
    var groupId: String?
    var orientation: String?
    var state: String?
    var canPlaceOnSurfaces: Bool?
    var backgroundTiles: Int?
    var canPlaceOnWalls: Bool?
}

final class FurnitureCatalog {
    static let shared = FurnitureCatalog()

    private var entries: [String: FurnitureCatalogEntry] = [:]

    private init() {
        loadHardcodedFallbacks()
        loadFromBundle()
    }

    func entry(for type: String) -> FurnitureCatalogEntry? {
        entries[type]
    }

    // swiftlint:disable function_body_length
    private func loadHardcodedFallbacks() {
        let fallbacks: [FurnitureCatalogEntry] = [
            // Original hand-drawn sprites
            .init(type: "desk", label: "Desk", footprintW: 2, footprintH: 2, spriteWidth: 32, spriteHeight: 32, isDesk: true, category: "desks"),
            .init(type: "chair", label: "Chair", footprintW: 1, footprintH: 1, spriteWidth: 16, spriteHeight: 16, isDesk: false, category: "chairs"),
            .init(type: "bookshelf", label: "Bookshelf", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "storage"),
            .init(type: "plant", label: "Plant", footprintW: 1, footprintH: 1, spriteWidth: 16, spriteHeight: 16, isDesk: false, category: "decor"),
            .init(type: "cooler", label: "Cooler", footprintW: 1, footprintH: 1, spriteWidth: 16, spriteHeight: 16, isDesk: false, category: "misc"),
            .init(type: "whiteboard", label: "Whiteboard", footprintW: 2, footprintH: 1, spriteWidth: 32, spriteHeight: 16, isDesk: false, category: "decor"),
            .init(type: "pc", label: "PC", footprintW: 1, footprintH: 1, spriteWidth: 16, spriteHeight: 16, isDesk: false, category: "electronics"),
            .init(type: "PC1", label: "PC", footprintW: 1, footprintH: 1, spriteWidth: 16, spriteHeight: 16, isDesk: false, category: "electronics", canPlaceOnSurfaces: true),
            .init(type: "lamp", label: "Lamp", footprintW: 1, footprintH: 1, spriteWidth: 16, spriteHeight: 16, isDesk: false, category: "decor"),
            // Generated from tileset metadata (92 ASSET_* entries)
            .init(type: "ASSET_4", label: "Solid Wooden Counter", footprintW: 3, footprintH: 2, spriteWidth: 48, spriteHeight: 32, isDesk: true, category: "desks", backgroundTiles: 1),
            .init(type: "ASSET_7", label: "Small White Counter", footprintW: 2, footprintH: 2, spriteWidth: 32, spriteHeight: 32, isDesk: true, category: "desks", backgroundTiles: 1),
            .init(type: "ASSET_15", label: "Small Plastic Counter", footprintW: 3, footprintH: 2, spriteWidth: 48, spriteHeight: 32, isDesk: true, category: "desks", backgroundTiles: 1),
            .init(type: "ASSET_17", label: "Small Wooden Bookshelf", footprintW: 2, footprintH: 2, spriteWidth: 32, spriteHeight: 32, isDesk: false, category: "storage", backgroundTiles: 1),
            .init(type: "ASSET_18", label: "Full Small Wooden Bookshelf", footprintW: 2, footprintH: 2, spriteWidth: 32, spriteHeight: 32, isDesk: false, category: "storage", backgroundTiles: 1),
            .init(type: "ASSET_23", label: "White Bookshelf", footprintW: 2, footprintH: 2, spriteWidth: 32, spriteHeight: 32, isDesk: false, category: "storage", backgroundTiles: 1),
            .init(type: "ASSET_24", label: "Full Small White Bookshelf", footprintW: 2, footprintH: 2, spriteWidth: 32, spriteHeight: 32, isDesk: false, category: "storage", backgroundTiles: 1),
            .init(type: "ASSET_27_A", label: "Large Table", footprintW: 2, footprintH: 4, spriteWidth: 32, spriteHeight: 64, isDesk: true, category: "desks", orientation: "front", backgroundTiles: 1),
            .init(type: "ASSET_27_B_A_A", label: "Tall Bookshelf", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "storage", backgroundTiles: 1),
            .init(type: "ASSET_27_B_A_B_A", label: "Full Tall Bookshelf", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "storage", backgroundTiles: 1),
            .init(type: "ASSET_27_B_A_B_B_A", label: "Tall Cabinet", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "storage", backgroundTiles: 1),
            .init(type: "ASSET_27_B_A_B_B_B_A", label: "Full Tall Cabinet", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "storage", backgroundTiles: 1),
            .init(type: "ASSET_28", label: "White Bookshelf", footprintW: 2, footprintH: 2, spriteWidth: 32, spriteHeight: 32, isDesk: false, category: "storage", backgroundTiles: 1),
            .init(type: "ASSET_29", label: "Full White Bookshelf", footprintW: 2, footprintH: 2, spriteWidth: 32, spriteHeight: 32, isDesk: false, category: "storage", backgroundTiles: 1),
            .init(type: "ASSET_32", label: "Cushioned Chair - Front", footprintW: 1, footprintH: 1, spriteWidth: 16, spriteHeight: 16, isDesk: false, category: "chairs", orientation: "front"),
            .init(type: "ASSET_38", label: "Cushioned Chair - Back", footprintW: 1, footprintH: 1, spriteWidth: 16, spriteHeight: 16, isDesk: false, category: "chairs", orientation: "back"),
            .init(type: "ASSET_33", label: "Cushioned Chair - Right", footprintW: 1, footprintH: 1, spriteWidth: 16, spriteHeight: 16, isDesk: false, category: "chairs", orientation: "right"),
            .init(type: "ASSET_34", label: "Cushioned Chair - Left", footprintW: 1, footprintH: 1, spriteWidth: 16, spriteHeight: 16, isDesk: false, category: "chairs", orientation: "left"),
            .init(type: "ASSET_35", label: "Rotating Chair - Front", footprintW: 1, footprintH: 1, spriteWidth: 16, spriteHeight: 16, isDesk: false, category: "chairs", orientation: "front"),
            .init(type: "ASSET_39", label: "Rotating Chair - Back", footprintW: 1, footprintH: 1, spriteWidth: 16, spriteHeight: 16, isDesk: false, category: "chairs", orientation: "back"),
            .init(type: "ASSET_36", label: "Rotating Chair - Right", footprintW: 1, footprintH: 1, spriteWidth: 16, spriteHeight: 16, isDesk: false, category: "chairs", orientation: "right"),
            .init(type: "ASSET_37", label: "Rotating Chair - Left", footprintW: 1, footprintH: 1, spriteWidth: 16, spriteHeight: 16, isDesk: false, category: "chairs", orientation: "left"),
            .init(type: "ASSET_42", label: "Water Cooler", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "misc", backgroundTiles: 1),
            .init(type: "ASSET_41_0_1", label: "Fridge", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "storage", backgroundTiles: 1),
            .init(type: "ASSET_40", label: "Snack Vending Machine", footprintW: 2, footprintH: 2, spriteWidth: 32, spriteHeight: 32, isDesk: false, category: "misc", backgroundTiles: 1),
            .init(type: "ASSET_44", label: "Trash Bin", footprintW: 1, footprintH: 1, spriteWidth: 16, spriteHeight: 16, isDesk: false, category: "misc"),
            .init(type: "ASSET_46", label: "Wooden Table - Vertical", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: true, category: "desks"),
            .init(type: "ASSET_49", label: "Small Wooden Stool", footprintW: 1, footprintH: 1, spriteWidth: 16, spriteHeight: 16, isDesk: false, category: "chairs"),
            .init(type: "ASSET_50_0_0", label: "Wooden Coffee Table", footprintW: 2, footprintH: 1, spriteWidth: 32, spriteHeight: 16, isDesk: true, category: "desks"),
            .init(type: "ASSET_51", label: "Coffee Mug", footprintW: 1, footprintH: 1, spriteWidth: 16, spriteHeight: 16, isDesk: false, category: "misc", canPlaceOnSurfaces: true),
            .init(type: "ASSET_55", label: "Coffee Machine", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "misc", canPlaceOnSurfaces: true, backgroundTiles: 1),
            .init(type: "ASSET_61", label: "Telephone", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "electronics", canPlaceOnSurfaces: true, backgroundTiles: 1, canPlaceOnWalls: true),
            .init(type: "ASSET_63", label: "Double Pane Wood Window", footprintW: 2, footprintH: 2, spriteWidth: 32, spriteHeight: 32, isDesk: false, category: "wall", canPlaceOnWalls: true),
            .init(type: "ASSET_64", label: "Double Window White", footprintW: 2, footprintH: 2, spriteWidth: 32, spriteHeight: 32, isDesk: false, category: "wall", canPlaceOnWalls: true),
            .init(type: "ASSET_65", label: "White Double Window", footprintW: 2, footprintH: 2, spriteWidth: 32, spriteHeight: 32, isDesk: false, category: "wall", canPlaceOnWalls: true),
            .init(type: "ASSET_71", label: "Small Book", footprintW: 1, footprintH: 1, spriteWidth: 16, spriteHeight: 16, isDesk: false, category: "decor", canPlaceOnSurfaces: true),
            .init(type: "ASSET_72", label: "Small Book", footprintW: 1, footprintH: 1, spriteWidth: 16, spriteHeight: 16, isDesk: false, category: "decor", canPlaceOnSurfaces: true),
            .init(type: "ASSET_78", label: "Monitor - Front - Off", footprintW: 1, footprintH: 1, spriteWidth: 16, spriteHeight: 16, isDesk: false, category: "electronics", orientation: "front", canPlaceOnSurfaces: true),
            .init(type: "ASSET_79", label: "Monitor - Front - On", footprintW: 1, footprintH: 1, spriteWidth: 16, spriteHeight: 16, isDesk: false, category: "electronics", orientation: "front", canPlaceOnSurfaces: true),
            .init(type: "ASSET_83", label: "White Wall Clock", footprintW: 1, footprintH: 1, spriteWidth: 16, spriteHeight: 16, isDesk: false, category: "wall", canPlaceOnWalls: true),
            .init(type: "ASSET_84", label: "Colorful Wall Clock", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "wall", canPlaceOnWalls: true),
            .init(type: "ASSET_74", label: "CRT Monitor - Off", footprintW: 1, footprintH: 1, spriteWidth: 16, spriteHeight: 16, isDesk: false, category: "electronics", canPlaceOnSurfaces: true),
            .init(type: "ASSET_76", label: "CRT Monitor - On", footprintW: 1, footprintH: 1, spriteWidth: 16, spriteHeight: 16, isDesk: false, category: "electronics", canPlaceOnSurfaces: true),
            .init(type: "ASSET_80", label: "Small Wooden Window", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "wall", canPlaceOnWalls: true),
            .init(type: "ASSET_81", label: "Small White Window", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "wall", canPlaceOnWalls: true),
            .init(type: "ASSET_82", label: "Small White Window", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "wall", canPlaceOnWalls: true),
            .init(type: "ASSET_90", label: "Full Computer with Coffee", footprintW: 2, footprintH: 2, spriteWidth: 32, spriteHeight: 32, isDesk: false, category: "electronics", orientation: "front", canPlaceOnSurfaces: true, backgroundTiles: 1),
            .init(type: "ASSET_92", label: "Full Computer with Coffee", footprintW: 2, footprintH: 2, spriteWidth: 32, spriteHeight: 32, isDesk: false, category: "electronics", orientation: "front", canPlaceOnSurfaces: true, backgroundTiles: 1),
            .init(type: "ASSET_98", label: "Laptop - Right", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "electronics", orientation: "right", canPlaceOnSurfaces: true, backgroundTiles: 1),
            .init(type: "ASSET_99", label: "Laptop - Left", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "electronics", orientation: "left", canPlaceOnSurfaces: true, backgroundTiles: 1),
            .init(type: "ASSET_100", label: "Paper - Side", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "decor", orientation: "front", canPlaceOnSurfaces: true, backgroundTiles: 1),
            .init(type: "ASSET_107", label: "Laptop - Front - Off", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "electronics", orientation: "front", canPlaceOnSurfaces: true, backgroundTiles: 1),
            .init(type: "ASSET_108", label: "Laptop - Front - On", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "electronics", orientation: "front", canPlaceOnSurfaces: true, backgroundTiles: 1),
            .init(type: "ASSET_110", label: "Paper - Front", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "decor", orientation: "front", canPlaceOnSurfaces: true, backgroundTiles: 1),
            .init(type: "ASSET_109", label: "Laptop - Back", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "electronics", orientation: "back", canPlaceOnSurfaces: true, backgroundTiles: 1),
            .init(type: "ASSET_101", label: "Landscape Painting", footprintW: 2, footprintH: 2, spriteWidth: 32, spriteHeight: 32, isDesk: false, category: "wall", canPlaceOnWalls: true),
            .init(type: "ASSET_102", label: "Landscape Painting", footprintW: 2, footprintH: 2, spriteWidth: 32, spriteHeight: 32, isDesk: false, category: "wall", canPlaceOnWalls: true),
            .init(type: "ASSET_103", label: "Small Painting", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "wall", canPlaceOnWalls: true),
            .init(type: "ASSET_104", label: "Small Painting", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "wall", canPlaceOnWalls: true),
            .init(type: "ASSET_105", label: "Small Painting", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "wall", canPlaceOnWalls: true),
            .init(type: "ASSET_106", label: "Framed Text", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "wall", canPlaceOnWalls: true),
            .init(type: "ASSET_122", label: "Small Wall Chalkboard", footprintW: 2, footprintH: 2, spriteWidth: 32, spriteHeight: 32, isDesk: false, category: "wall", canPlaceOnWalls: true),
            .init(type: "ASSET_118", label: "Small Chart", footprintW: 2, footprintH: 2, spriteWidth: 32, spriteHeight: 32, isDesk: false, category: "wall", canPlaceOnWalls: true),
            .init(type: "ASSET_119", label: "Small Chart", footprintW: 2, footprintH: 2, spriteWidth: 32, spriteHeight: 32, isDesk: false, category: "wall", canPlaceOnWalls: true),
            .init(type: "ASSET_120", label: "Chart", footprintW: 2, footprintH: 2, spriteWidth: 32, spriteHeight: 32, isDesk: false, category: "wall", canPlaceOnWalls: true),
            .init(type: "ASSET_114", label: "CRT Monitor - Back", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "electronics", orientation: "back", canPlaceOnSurfaces: true, backgroundTiles: 1),
            .init(type: "ASSET_121", label: "Monitor - Back", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "electronics", orientation: "back", backgroundTiles: 1),
            .init(type: "ASSET_123", label: "Server", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "electronics", canPlaceOnSurfaces: true, backgroundTiles: 1),
            .init(type: "ASSET_126", label: "Desktop Printer", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "electronics", canPlaceOnSurfaces: true, backgroundTiles: 1),
            .init(type: "ASSET_127", label: "Crate", footprintW: 1, footprintH: 1, spriteWidth: 16, spriteHeight: 16, isDesk: false, category: "storage", canPlaceOnSurfaces: true),
            .init(type: "ASSET_133_0_0", label: "Small Plant", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "decor", canPlaceOnSurfaces: true, backgroundTiles: 1),
            .init(type: "ASSET_134", label: "Chart", footprintW: 2, footprintH: 2, spriteWidth: 32, spriteHeight: 32, isDesk: false, category: "wall", canPlaceOnWalls: true),
            .init(type: "ASSET_138", label: "Crates", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "storage", backgroundTiles: 1),
            .init(type: "ASSET_135", label: "Crates", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "storage", backgroundTiles: 1),
            .init(type: "ASSET_136", label: "Crates", footprintW: 2, footprintH: 2, spriteWidth: 32, spriteHeight: 32, isDesk: false, category: "storage"),
            .init(type: "ASSET_137", label: "Crates", footprintW: 2, footprintH: 2, spriteWidth: 32, spriteHeight: 32, isDesk: false, category: "storage"),
            .init(type: "ASSET_139", label: "Crates", footprintW: 2, footprintH: 2, spriteWidth: 32, spriteHeight: 32, isDesk: false, category: "storage", backgroundTiles: 1),
            .init(type: "ASSET_132", label: "Small Plant", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "decor", canPlaceOnSurfaces: true, backgroundTiles: 1),
            .init(type: "ASSET_140", label: "Plant", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "decor", backgroundTiles: 1),
            .init(type: "ASSET_141", label: "Plant", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "decor", backgroundTiles: 1),
            .init(type: "ASSET_142", label: "Plant", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "decor", backgroundTiles: 1),
            .init(type: "ASSET_143", label: "Plant", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "decor", backgroundTiles: 1),
            .init(type: "ASSET_145", label: "Square Pattern Mat", footprintW: 2, footprintH: 1, spriteWidth: 32, spriteHeight: 16, isDesk: false, category: "decor"),
            .init(type: "ASSET_148", label: "Chess Board Mat", footprintW: 2, footprintH: 1, spriteWidth: 32, spriteHeight: 16, isDesk: false, category: "decor"),
            .init(type: "ASSET_150", label: "Circle Pattern Mat", footprintW: 2, footprintH: 1, spriteWidth: 32, spriteHeight: 16, isDesk: false, category: "decor"),
            .init(type: "ASSET_151", label: "Microwave", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "misc", canPlaceOnSurfaces: true, backgroundTiles: 1),
            .init(type: "ASSET_NEW_106", label: "Wooden Table", footprintW: 3, footprintH: 2, spriteWidth: 48, spriteHeight: 32, isDesk: true, category: "desks", backgroundTiles: 1),
            .init(type: "ASSET_NEW_107", label: "Plain Wooden Table", footprintW: 3, footprintH: 2, spriteWidth: 48, spriteHeight: 32, isDesk: true, category: "desks", backgroundTiles: 1),
            .init(type: "ASSET_NEW_108", label: "Large Cushioned Chair", footprintW: 2, footprintH: 1, spriteWidth: 32, spriteHeight: 16, isDesk: false, category: "chairs", orientation: "front"),
            .init(type: "ASSET_NEW_109", label: "Large Cushioned Chair", footprintW: 2, footprintH: 1, spriteWidth: 32, spriteHeight: 16, isDesk: false, category: "chairs", orientation: "back"),
            .init(type: "ASSET_NEW_110", label: "Large Cushioned Chair", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "chairs", orientation: "right"),
            .init(type: "ASSET_NEW_111", label: "Large Cushioned Chair", footprintW: 1, footprintH: 2, spriteWidth: 16, spriteHeight: 32, isDesk: false, category: "chairs", orientation: "left"),
            .init(type: "ASSET_NEW_112", label: "Large Coffee Table", footprintW: 2, footprintH: 2, spriteWidth: 32, spriteHeight: 32, isDesk: true, category: "desks", backgroundTiles: 1),
        ]
        for entry in fallbacks {
            entries[entry.type] = entry
        }
    }
    // swiftlint:enable function_body_length

    private func loadFromBundle() {
        guard let url = Bundle.main.url(forResource: "furniture-catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode([FurnitureCatalogJSON].self, from: data) else {
            return
        }

        for item in catalog {
            let entry = FurnitureCatalogEntry(
                type: item.id,
                label: item.label,
                footprintW: item.footprintW,
                footprintH: item.footprintH,
                spriteWidth: item.width,
                spriteHeight: item.height,
                isDesk: item.isDesk,
                category: item.category,
                orientation: item.orientation,
                canPlaceOnSurfaces: item.canPlaceOnSurfaces ?? false,
                backgroundTiles: item.backgroundTiles ?? 0,
                canPlaceOnWalls: item.canPlaceOnWalls ?? false
            )
            entries[item.id] = entry
        }
    }
}
