import Foundation

enum Pathfinding {

    static func isWalkable(col: Int, row: Int, tileMap: [[TileType]], blockedTiles: Set<TileCoord>) -> Bool {
        let rows = tileMap.count
        let cols = rows > 0 ? tileMap[0].count : 0
        guard row >= 0, row < rows, col >= 0, col < cols else { return false }
        let t = tileMap[row][col]
        if t == .wall || t == .void_ { return false }
        if blockedTiles.contains(TileCoord(col: col, row: row)) { return false }
        return true
    }

    static func getWalkableTiles(tileMap: [[TileType]], blockedTiles: Set<TileCoord>) -> [TileCoord] {
        let rows = tileMap.count
        let cols = rows > 0 ? tileMap[0].count : 0
        var tiles: [TileCoord] = []
        for r in 0..<rows {
            for c in 0..<cols {
                if isWalkable(col: c, row: r, tileMap: tileMap, blockedTiles: blockedTiles) {
                    tiles.append(TileCoord(col: c, row: r))
                }
            }
        }
        return tiles
    }

    static func findPath(
        from start: TileCoord,
        to end: TileCoord,
        tileMap: [[TileType]],
        blockedTiles: Set<TileCoord>
    ) -> [TileCoord] {
        if start == end { return [] }

        guard isWalkable(col: end.col, row: end.row, tileMap: tileMap, blockedTiles: blockedTiles) else {
            return []
        }

        var visited = Set<TileCoord>()
        visited.insert(start)

        var parent: [TileCoord: TileCoord] = [:]
        var queue: [TileCoord] = [start]
        var head = 0

        let dirs = [(0, -1), (0, 1), (-1, 0), (1, 0)]

        while head < queue.count {
            let curr = queue[head]
            head += 1

            if curr == end {
                var path: [TileCoord] = []
                var k = end
                while k != start {
                    path.append(k)
                    k = parent[k]!
                }
                path.reverse()
                return path
            }

            for (dc, dr) in dirs {
                let next = TileCoord(col: curr.col + dc, row: curr.row + dr)
                guard !visited.contains(next) else { continue }
                guard isWalkable(col: next.col, row: next.row, tileMap: tileMap, blockedTiles: blockedTiles) else { continue }
                visited.insert(next)
                parent[next] = curr
                queue.append(next)
            }
        }

        return []
    }
}
