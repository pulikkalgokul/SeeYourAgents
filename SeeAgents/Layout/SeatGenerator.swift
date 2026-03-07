import Foundation

enum SeatGenerator {

    static func layoutToSeats(furniture: [PlacedFurniture]) -> [String: Seat] {
        let catalog = FurnitureCatalog.shared
        var seats: [String: Seat] = [:]

        // Build set of all desk tiles
        var deskTiles = Set<TileCoord>()
        for item in furniture {
            guard let entry = catalog.entry(for: item.type), entry.isDesk else { continue }
            for dr in 0..<entry.footprintH {
                for dc in 0..<entry.footprintW {
                    deskTiles.insert(TileCoord(col: item.col + dc, row: item.row + dr))
                }
            }
        }

        let dirs: [(dc: Int, dr: Int, facing: CharacterDirection)] = [
            (0, -1, .up),
            (0, 1, .down),
            (-1, 0, .left),
            (1, 0, .right),
        ]

        for item in furniture {
            guard let entry = catalog.entry(for: item.type), entry.category == "chairs" else { continue }

            var seatCount = 0
            for dr in 0..<entry.footprintH {
                for dc in 0..<entry.footprintW {
                    let tileCol = item.col + dc
                    let tileRow = item.row + dr

                    var facingDir: CharacterDirection = .down
                    if let orientation = entry.orientation {
                        facingDir = orientationToFacing(orientation)
                    } else {
                        for d in dirs {
                            if deskTiles.contains(TileCoord(col: tileCol + d.dc, row: tileRow + d.dr)) {
                                facingDir = d.facing
                                break
                            }
                        }
                    }

                    let seatUid = seatCount == 0 ? item.uid : "\(item.uid):\(seatCount)"
                    seats[seatUid] = Seat(
                        uid: seatUid,
                        seatCol: tileCol,
                        seatRow: tileRow,
                        facingDir: facingDir,
                        assigned: false
                    )
                    seatCount += 1
                }
            }
        }

        return seats
    }

    static func getBlockedTilesForPathfinding(furniture: [PlacedFurniture], seatTiles: Set<TileCoord>) -> Set<TileCoord> {
        let catalog = FurnitureCatalog.shared
        var blocked = Set<TileCoord>()

        for item in furniture {
            guard let entry = catalog.entry(for: item.type) else { continue }
            let bgRows = entry.backgroundTiles
            for dr in 0..<entry.footprintH {
                if dr < bgRows { continue }
                for dc in 0..<entry.footprintW {
                    let coord = TileCoord(col: item.col + dc, row: item.row + dr)
                    if !seatTiles.contains(coord) {
                        blocked.insert(coord)
                    }
                }
            }
        }

        return blocked
    }

    private static func orientationToFacing(_ orientation: String) -> CharacterDirection {
        switch orientation {
        case "front": return .down
        case "back": return .up
        case "left": return .left
        case "right": return .right
        default: return .down
        }
    }
}
