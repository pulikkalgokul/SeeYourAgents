import Foundation

enum CharacterDirection: Int {
    case down = 0
    case up = 1
    case right = 2
    case left = 3
}

enum CharacterState {
    case typing
    case idle
    case walk
}

enum BubbleType {
    case permission
    case waiting
}

enum MatrixEffect {
    case spawn
    case despawn
}

struct Seat {
    let uid: String
    let seatCol: Int
    let seatRow: Int
    let facingDir: CharacterDirection
    var assigned: Bool
}

struct TileCoord: Hashable {
    let col: Int
    let row: Int
}
