import Foundation

func layoutToTileMap(_ layout: OfficeLayout) -> [[TileType]] {
    var map: [[TileType]] = []
    for r in 0..<layout.rows {
        var row: [TileType] = []
        for c in 0..<layout.cols {
            let raw = layout.tiles[r * layout.cols + c]
            row.append(TileType(rawValue: raw) ?? .void_)
        }
        map.append(row)
    }
    return map
}
