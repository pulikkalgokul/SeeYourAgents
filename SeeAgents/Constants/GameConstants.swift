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
