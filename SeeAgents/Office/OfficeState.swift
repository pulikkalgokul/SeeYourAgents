import SpriteKit

final class OfficeState {
    let layout: OfficeLayout
    let tileMap: [[TileType]]
    var seats: [String: Seat]
    var blockedTiles: Set<TileCoord>
    let walkableTiles: [TileCoord]
    var characters: [Int: OfficeCharacter] = [:]

    init(layout: OfficeLayout) {
        self.layout = layout
        self.tileMap = layoutToTileMap(layout)

        let seats = SeatGenerator.layoutToSeats(furniture: layout.furniture)
        self.seats = seats

        let seatTileSet = Set(seats.values.map { TileCoord(col: $0.seatCol, row: $0.seatRow) })
        self.blockedTiles = SeatGenerator.getBlockedTilesForPathfinding(
            furniture: layout.furniture,
            seatTiles: seatTileSet
        )
        self.walkableTiles = Pathfinding.getWalkableTiles(tileMap: self.tileMap, blockedTiles: self.blockedTiles)

        print("[OfficeState] Init: \(seats.count) seats, \(blockedTiles.count) blocked, \(walkableTiles.count) walkable")
    }

    // MARK: - Agent Lifecycle

    func addAgent(id: Int) {
        guard characters[id] == nil else { return }

        let pick = pickDiversePalette()
        let seatId = findFreeSeat()

        var seat: Seat?
        if let seatId {
            seats[seatId]?.assigned = true
            seat = seats[seatId]
        }

        let ch = OfficeCharacter(
            id: id,
            palette: pick.palette,
            seatId: seatId,
            seat: seat,
            hueShift: pick.hueShift
        )

        if seatId == nil, !walkableTiles.isEmpty {
            let spawn = walkableTiles.randomElement()!
            ch.x = CGFloat(spawn.col) * OfficeConstants.tileSize + OfficeConstants.tileSize / 2
            ch.y = CGFloat(spawn.row) * OfficeConstants.tileSize + OfficeConstants.tileSize / 2
            ch.tileCol = spawn.col
            ch.tileRow = spawn.row
        }

        ch.matrixEffect = .spawn
        ch.matrixEffectTimer = 0
        ch.spriteNode.alpha = 0

        characters[id] = ch
        print("[OfficeState] Added agent \(id), palette=\(pick.palette), seat=\(seatId ?? "none")")
    }

    func removeAgent(id: Int) {
        guard let ch = characters[id] else { return }
        if ch.matrixEffect == .despawn { return }

        if let seatId = ch.seatId {
            seats[seatId]?.assigned = false
        }

        ch.matrixEffect = .despawn
        ch.matrixEffectTimer = 0
        ch.bubbleType = nil
        print("[OfficeState] Removing agent \(id)")
    }

    func setAgentActive(id: Int, active: Bool) {
        guard let ch = characters[id] else { return }
        ch.isActive = active
        if !active {
            ch.seatTimer = -1
            ch.path = []
            ch.moveProgress = 0
        }
    }

    func setAgentTool(id: Int, tool: String?) {
        characters[id]?.currentTool = tool
    }

    func showPermissionBubble(id: Int) {
        guard let ch = characters[id] else { return }
        ch.bubbleType = .permission
        ch.bubbleTimer = 0
    }

    func clearPermissionBubble(id: Int) {
        guard let ch = characters[id], ch.bubbleType == .permission else { return }
        ch.bubbleType = nil
        ch.bubbleTimer = 0
    }

    func showWaitingBubble(id: Int) {
        guard let ch = characters[id] else { return }
        ch.bubbleType = .waiting
        ch.bubbleTimer = 2.0
    }

    // MARK: - Update Loop

    func update(dt: TimeInterval) {
        var toDelete: [Int] = []

        for ch in characters.values {
            // Handle spawn/despawn
            if let effect = ch.matrixEffect {
                ch.matrixEffectTimer += dt
                let progress = ch.matrixEffectTimer / CharacterConstants.spawnDuration

                switch effect {
                case .spawn:
                    ch.spriteNode.alpha = min(CGFloat(progress), 1)
                    if ch.matrixEffectTimer >= CharacterConstants.spawnDuration {
                        ch.matrixEffect = nil
                        ch.matrixEffectTimer = 0
                        ch.spriteNode.alpha = 1
                    }
                case .despawn:
                    ch.spriteNode.alpha = max(1 - CGFloat(progress), 0)
                    if ch.matrixEffectTimer >= CharacterConstants.spawnDuration {
                        toDelete.append(ch.id)
                    }
                }
                continue
            }

            // Run FSM with own seat unblocked
            withOwnSeatUnblocked(ch) {
                CharacterFSM.updateCharacter(
                    ch,
                    dt: dt,
                    walkableTiles: self.walkableTiles,
                    seats: self.seats,
                    tileMap: self.tileMap,
                    blockedTiles: self.blockedTiles
                )
            }

            // Tick bubble
            if ch.bubbleType == .waiting {
                ch.bubbleTimer -= dt
                if ch.bubbleTimer <= 0 {
                    ch.bubbleType = nil
                    ch.bubbleTimer = 0
                }
            }
        }

        for id in toDelete {
            characters[id]?.spriteNode.removeFromParent()
            characters[id]?.bubbleNode?.removeFromParent()
            characters.removeValue(forKey: id)
        }
    }

    // MARK: - Private Helpers

    private func findFreeSeat() -> String? {
        for (uid, seat) in seats {
            if !seat.assigned { return uid }
        }
        return nil
    }

    private func pickDiversePalette() -> (palette: Int, hueShift: CGFloat) {
        var counts = [Int](repeating: 0, count: CharacterConstants.paletteCount)
        for ch in characters.values {
            counts[ch.palette] += 1
        }
        let minCount = counts.min() ?? 0
        var available: [Int] = []
        for i in 0..<CharacterConstants.paletteCount {
            if counts[i] == minCount { available.append(i) }
        }
        let palette = available.randomElement() ?? 0
        var hueShift: CGFloat = 0
        if minCount > 0 {
            hueShift = CharacterConstants.hueShiftMinDeg + CGFloat.random(in: 0..<CharacterConstants.hueShiftRangeDeg)
        }
        return (palette, hueShift)
    }

    private func withOwnSeatUnblocked(_ ch: OfficeCharacter, _ fn: () -> Void) {
        guard let seatId = ch.seatId, let seat = seats[seatId] else {
            fn()
            return
        }
        let key = TileCoord(col: seat.seatCol, row: seat.seatRow)
        let wasBlocked = blockedTiles.contains(key)
        blockedTiles.remove(key)
        fn()
        if wasBlocked {
            blockedTiles.insert(key)
        }
    }
}
