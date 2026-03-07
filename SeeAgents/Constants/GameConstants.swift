import Foundation

enum GameConstants {
    // MARK: - File Watching
    static let fileWatcherPollInterval: TimeInterval = 1.0
    static let projectScanInterval: TimeInterval = 2.0
    static let jsonlPollInterval: TimeInterval = 1.0

    // MARK: - Timer Delays
    static let toolDoneDelay: TimeInterval = 0.3
    static let permissionTimerDelay: TimeInterval = 7.0
    static let textIdleDelay: TimeInterval = 5.0

    // MARK: - Display Truncation
    static let bashCommandDisplayMaxLength = 30
    static let taskDescriptionDisplayMaxLength = 40

    // MARK: - Paths
    static let claudeProjectsPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.claude/projects"
    }()

    // MARK: - Permission Exempt Tools
    static let permissionExemptTools: Set<String> = ["Task", "AskUserQuestion"]
}

// MARK: - Character Constants

enum CharacterConstants {
    // Animation
    static let walkSpeedPxPerSec: CGFloat = 48
    static let walkFrameDuration: TimeInterval = 0.15
    static let typeFrameDuration: TimeInterval = 0.3

    // Wander AI
    static let wanderPauseMin: TimeInterval = 2.0
    static let wanderPauseMax: TimeInterval = 20.0
    static let wanderMovesBeforeRestMin = 3
    static let wanderMovesBeforeRestMax = 6
    static let seatRestMin: TimeInterval = 120.0
    static let seatRestMax: TimeInterval = 240.0

    // Sprite sheet layout
    static let spriteWidth: CGFloat = 16
    static let spriteFrameHeight: CGFloat = 32
    static let spriteBodyHeight: CGFloat = 24
    static let sheetCols = 7
    static let sheetDirectionRows = 3
    static let paletteCount = 6

    // Rendering
    static let sittingOffsetPx: CGFloat = 6
    static let zSortOffset: CGFloat = 0.5
    static let maxDeltaTime: TimeInterval = 0.1

    // Reading tools
    static let readingTools: Set<String> = ["Read", "Grep", "Glob", "WebFetch", "WebSearch"]

    // Spawn/despawn
    static let spawnDuration: TimeInterval = 0.3
    static let hueShiftMinDeg: CGFloat = 45
    static let hueShiftRangeDeg: CGFloat = 271

    // Inactive seat timer
    static let inactiveSeatTimerMin: TimeInterval = 3.0
    static let inactiveSeatTimerRange: TimeInterval = 2.0
}
