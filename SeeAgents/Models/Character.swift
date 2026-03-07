import SpriteKit

final class OfficeCharacter {
    let id: Int
    var state: CharacterState = .typing
    var dir: CharacterDirection = .down
    var x: CGFloat = 0
    var y: CGFloat = 0
    var tileCol: Int = 0
    var tileRow: Int = 0
    var path: [TileCoord] = []
    var moveProgress: CGFloat = 0
    var currentTool: String?
    let palette: Int
    let hueShift: CGFloat
    var frame: Int = 0
    var frameTimer: TimeInterval = 0
    var wanderTimer: TimeInterval = 0
    var wanderCount: Int = 0
    var wanderLimit: Int
    var isActive: Bool = true
    var seatId: String?
    var bubbleType: BubbleType?
    var bubbleTimer: TimeInterval = 0
    var seatTimer: TimeInterval = 0
    var matrixEffect: MatrixEffect?
    var matrixEffectTimer: TimeInterval = 0

    let spriteNode: SKSpriteNode
    var bubbleNode: SKLabelNode?

    init(id: Int, palette: Int, seatId: String?, seat: Seat?, hueShift: CGFloat = 0) {
        self.id = id
        self.palette = palette
        self.hueShift = hueShift
        self.seatId = seatId
        self.wanderLimit = Int.random(
            in: CharacterConstants.wanderMovesBeforeRestMin...CharacterConstants.wanderMovesBeforeRestMax
        )

        let col = seat?.seatCol ?? 1
        let row = seat?.seatRow ?? 1
        let tileSize = OfficeConstants.tileSize
        self.tileCol = col
        self.tileRow = row
        self.x = CGFloat(col) * tileSize + tileSize / 2
        self.y = CGFloat(row) * tileSize + tileSize / 2
        self.dir = seat?.facingDir ?? .down

        self.spriteNode = SKSpriteNode()
        self.spriteNode.anchorPoint = CGPoint(x: 0.5, y: 0)
        self.spriteNode.size = CGSize(
            width: CharacterConstants.spriteWidth,
            height: CharacterConstants.spriteFrameHeight
        )
    }
}
