import SpriteKit

enum CharacterFSM {

    static func updateCharacter(
        _ ch: OfficeCharacter,
        dt: TimeInterval,
        walkableTiles: [TileCoord],
        seats: [String: Seat],
        tileMap: [[TileType]],
        blockedTiles: Set<TileCoord>
    ) {
        ch.frameTimer += dt

        switch ch.state {
        case .typing:
            updateTyping(ch, dt: dt)

        case .idle:
            updateIdle(ch, dt: dt, walkableTiles: walkableTiles, seats: seats, tileMap: tileMap, blockedTiles: blockedTiles)

        case .walk:
            updateWalk(ch, dt: dt, seats: seats, tileMap: tileMap, blockedTiles: blockedTiles)
        }
    }

    // MARK: - TYPE State

    private static func updateTyping(_ ch: OfficeCharacter, dt: TimeInterval) {
        if ch.frameTimer >= CharacterConstants.typeFrameDuration {
            ch.frameTimer -= CharacterConstants.typeFrameDuration
            ch.frame = (ch.frame + 1) % 2
        }

        if !ch.isActive {
            if ch.seatTimer > 0 {
                ch.seatTimer -= dt
                return
            }
            ch.seatTimer = 0
            ch.state = .idle
            ch.frame = 0
            ch.frameTimer = 0
            ch.wanderTimer = .random(in: CharacterConstants.wanderPauseMin...CharacterConstants.wanderPauseMax)
            ch.wanderCount = 0
            ch.wanderLimit = Int.random(
                in: CharacterConstants.wanderMovesBeforeRestMin...CharacterConstants.wanderMovesBeforeRestMax
            )
        }
    }

    // MARK: - IDLE State

    private static func updateIdle(
        _ ch: OfficeCharacter,
        dt: TimeInterval,
        walkableTiles: [TileCoord],
        seats: [String: Seat],
        tileMap: [[TileType]],
        blockedTiles: Set<TileCoord>
    ) {
        ch.frame = 0
        if ch.seatTimer < 0 { ch.seatTimer = 0 }

        // Became active -> pathfind to seat
        if ch.isActive {
            guard let seatId = ch.seatId, let seat = seats[seatId] else {
                ch.state = .typing
                ch.frame = 0
                ch.frameTimer = 0
                return
            }
            let path = Pathfinding.findPath(
                from: TileCoord(col: ch.tileCol, row: ch.tileRow),
                to: TileCoord(col: seat.seatCol, row: seat.seatRow),
                tileMap: tileMap,
                blockedTiles: blockedTiles
            )
            if !path.isEmpty {
                ch.path = path
                ch.moveProgress = 0
                ch.state = .walk
                ch.frame = 0
                ch.frameTimer = 0
            } else {
                ch.state = .typing
                ch.dir = seat.facingDir
                ch.frame = 0
                ch.frameTimer = 0
            }
            return
        }

        // Countdown wander timer
        ch.wanderTimer -= dt
        if ch.wanderTimer <= 0 {
            // Check if wandered enough -> return to seat
            if ch.wanderCount >= ch.wanderLimit, let seatId = ch.seatId, let seat = seats[seatId] {
                let path = Pathfinding.findPath(
                    from: TileCoord(col: ch.tileCol, row: ch.tileRow),
                    to: TileCoord(col: seat.seatCol, row: seat.seatRow),
                    tileMap: tileMap,
                    blockedTiles: blockedTiles
                )
                if !path.isEmpty {
                    ch.path = path
                    ch.moveProgress = 0
                    ch.state = .walk
                    ch.frame = 0
                    ch.frameTimer = 0
                    return
                }
            }

            // Pick random walkable tile
            if !walkableTiles.isEmpty {
                let target = walkableTiles.randomElement()!
                let path = Pathfinding.findPath(
                    from: TileCoord(col: ch.tileCol, row: ch.tileRow),
                    to: target,
                    tileMap: tileMap,
                    blockedTiles: blockedTiles
                )
                if !path.isEmpty {
                    ch.path = path
                    ch.moveProgress = 0
                    ch.state = .walk
                    ch.frame = 0
                    ch.frameTimer = 0
                    ch.wanderCount += 1
                }
            }
            ch.wanderTimer = .random(in: CharacterConstants.wanderPauseMin...CharacterConstants.wanderPauseMax)
        }
    }

    // MARK: - WALK State

    private static func updateWalk(
        _ ch: OfficeCharacter,
        dt: TimeInterval,
        seats: [String: Seat],
        tileMap: [[TileType]],
        blockedTiles: Set<TileCoord>
    ) {
        let tileSize = OfficeConstants.tileSize

        // Walk animation
        if ch.frameTimer >= CharacterConstants.walkFrameDuration {
            ch.frameTimer -= CharacterConstants.walkFrameDuration
            ch.frame = (ch.frame + 1) % 4
        }

        if ch.path.isEmpty {
            // Path complete
            let center = tileCenter(ch.tileCol, ch.tileRow)
            ch.x = center.x
            ch.y = center.y

            if ch.isActive {
                if let seatId = ch.seatId, let seat = seats[seatId],
                   ch.tileCol == seat.seatCol && ch.tileRow == seat.seatRow {
                    ch.state = .typing
                    ch.dir = seat.facingDir
                } else if ch.seatId == nil {
                    ch.state = .typing
                } else {
                    ch.state = .idle
                }
            } else {
                // Check if at assigned seat
                if let seatId = ch.seatId, let seat = seats[seatId],
                   ch.tileCol == seat.seatCol && ch.tileRow == seat.seatRow {
                    ch.state = .typing
                    ch.dir = seat.facingDir
                    if ch.seatTimer < 0 {
                        ch.seatTimer = 0
                    } else {
                        ch.seatTimer = .random(in: CharacterConstants.seatRestMin...CharacterConstants.seatRestMax)
                    }
                    ch.wanderCount = 0
                    ch.wanderLimit = Int.random(
                        in: CharacterConstants.wanderMovesBeforeRestMin...CharacterConstants.wanderMovesBeforeRestMax
                    )
                    ch.frame = 0
                    ch.frameTimer = 0
                    return
                }
                ch.state = .idle
                ch.wanderTimer = .random(in: CharacterConstants.wanderPauseMin...CharacterConstants.wanderPauseMax)
            }
            ch.frame = 0
            ch.frameTimer = 0
            return
        }

        // Move toward next tile
        let nextTile = ch.path[0]
        ch.dir = directionBetween(
            fromCol: ch.tileCol, fromRow: ch.tileRow,
            toCol: nextTile.col, toRow: nextTile.row
        )

        ch.moveProgress += (CharacterConstants.walkSpeedPxPerSec / tileSize) * CGFloat(dt)

        let fromCenter = tileCenter(ch.tileCol, ch.tileRow)
        let toCenter = tileCenter(nextTile.col, nextTile.row)
        let t = min(ch.moveProgress, 1)
        ch.x = fromCenter.x + (toCenter.x - fromCenter.x) * t
        ch.y = fromCenter.y + (toCenter.y - fromCenter.y) * t

        if ch.moveProgress >= 1 {
            ch.tileCol = nextTile.col
            ch.tileRow = nextTile.row
            ch.x = toCenter.x
            ch.y = toCenter.y
            ch.path.removeFirst()
            ch.moveProgress = 0
        }

        // If became active while wandering, repath to seat
        if ch.isActive, let seatId = ch.seatId, let seat = seats[seatId] {
            let lastStep = ch.path.last
            if lastStep == nil || lastStep!.col != seat.seatCol || lastStep!.row != seat.seatRow {
                let newPath = Pathfinding.findPath(
                    from: TileCoord(col: ch.tileCol, row: ch.tileRow),
                    to: TileCoord(col: seat.seatCol, row: seat.seatRow),
                    tileMap: tileMap,
                    blockedTiles: blockedTiles
                )
                if !newPath.isEmpty {
                    ch.path = newPath
                    ch.moveProgress = 0
                }
            }
        }
    }

    // MARK: - Texture Selection

    static func getCharacterTexture(
        _ ch: OfficeCharacter,
        sprites: CharacterSprites
    ) -> SKTexture {
        let dirIndex = ch.dir.rawValue

        switch ch.state {
        case .typing:
            if let tool = ch.currentTool, CharacterConstants.readingTools.contains(tool) {
                return sprites.reading[dirIndex][ch.frame % 2]
            }
            return sprites.typing[dirIndex][ch.frame % 2]
        case .walk:
            return sprites.walk[dirIndex][ch.frame % 4]
        case .idle:
            return sprites.walk[dirIndex][1]
        }
    }

    // MARK: - Helpers

    private static func tileCenter(_ col: Int, _ row: Int) -> CGPoint {
        let tileSize = OfficeConstants.tileSize
        return CGPoint(
            x: CGFloat(col) * tileSize + tileSize / 2,
            y: CGFloat(row) * tileSize + tileSize / 2
        )
    }

    private static func directionBetween(fromCol: Int, fromRow: Int, toCol: Int, toRow: Int) -> CharacterDirection {
        let dc = toCol - fromCol
        let dr = toRow - fromRow
        if dc > 0 { return .right }
        if dc < 0 { return .left }
        if dr > 0 { return .down }
        return .up
    }
}
