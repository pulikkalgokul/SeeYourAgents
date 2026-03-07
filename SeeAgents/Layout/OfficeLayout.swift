import Foundation

enum TileType: Int, Codable {
    case wall = 0
    case floor1 = 1
    case floor2 = 2
    case floor3 = 3
    case floor4 = 4
    case floor5 = 5
    case floor6 = 6
    case floor7 = 7
    case void_ = 8

    var isFloor: Bool {
        rawValue >= 1 && rawValue <= 7
    }

    var floorPatternIndex: Int {
        rawValue
    }
}

struct FloorColor: Codable, Hashable {
    let h: Double
    let s: Double
    let b: Double
    let c: Double
    var colorize: Bool?

    enum CodingKeys: String, CodingKey {
        case h, s, b, c, colorize
    }
}

struct PlacedFurniture: Codable {
    let uid: String
    let type: String
    let col: Int
    let row: Int
    var color: FloorColor?
}

struct OfficeLayout: Codable {
    let version: Int
    let cols: Int
    let rows: Int
    let tiles: [Int]
    let furniture: [PlacedFurniture]
    var tileColors: [FloorColor?]?

    func tileType(at index: Int) -> TileType {
        TileType(rawValue: tiles[index]) ?? .void_
    }
}
