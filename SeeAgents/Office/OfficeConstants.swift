import Foundation
import CoreGraphics

enum OfficeConstants {
    static let tileSize: CGFloat = 16

    // Wall sprite sheet: 4x4 grid of 16x32 pieces
    static let wallPieceWidth: Int = 16
    static let wallPieceHeight: Int = 32
    static let wallGridCols: Int = 4
    static let wallBitmaskCount: Int = 16

    // Colors
    static let wallBaseColor = CGColor(red: 0x3A/255.0, green: 0x3A/255.0, blue: 0x5C/255.0, alpha: 1)
    static let fallbackFloorGray: CGFloat = 128.0 / 255.0

    // Floor
    static let floorPatternCount: Int = 7

    // Zoom
    static let zoomMin: CGFloat = 1
    static let zoomMax: CGFloat = 10
    static let zoomDefault: CGFloat = 3
}
