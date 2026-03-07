import Foundation
import os

private let logger = Logger(subsystem: "com.personal.SeeAgents", category: "ProjectScanner")

/// Scans `~/.claude/projects/` for active JSONL session files.
///
/// Strategy: every scan checks all JSONL files. Reports any file that has been
/// modified within the activity window. AgentManager deduplicates by file path.
/// Also tracks file sizes to detect newly-written-to files (even old ones that
/// become active again).
@preconcurrency
final class ProjectScanner: @unchecked Sendable {
    private let onNewSession: @MainActor @Sendable (String, String) -> Void
    private var trackedFiles: [String: UInt64] = [:]  // path -> last known size
    private var scanTimer: DispatchSourceTimer?
    private var isRunning = false

    /// How recently a file must have been modified to be considered active.
    private let activityWindow: TimeInterval = 300  // 5 minutes

    init(onNewSession: @MainActor @Sendable @escaping (String, String) -> Void) {
        self.onNewSession = onNewSession
    }

    // MARK: - Start / Stop

    func start() {
        guard !isRunning else { return }
        isRunning = true

        // Immediate first scan
        scan()

        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(
            deadline: .now() + GameConstants.projectScanInterval,
            repeating: GameConstants.projectScanInterval
        )
        timer.setEventHandler { [weak self] in
            self?.scan()
        }
        timer.resume()
        scanTimer = timer
    }

    func stop() {
        isRunning = false
        scanTimer?.cancel()
        scanTimer = nil
    }

    /// Mark a file as tracked at its current size so it won't be re-reported
    /// unless it grows.
    func markTracked(_ path: String) {
        let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? UInt64) ?? 0
        trackedFiles[path] = size
    }

    // MARK: - Scanning

    private func scan() {
        let fm = FileManager.default
        let projectsPath = GameConstants.claudeProjectsPath
        guard let projectDirs = try? fm.contentsOfDirectory(atPath: projectsPath) else { return }

        for dir in projectDirs {
            let projectDir = "\(projectsPath)/\(dir)"
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: projectDir, isDirectory: &isDir), isDir.boolValue else { continue }

            guard let files = try? fm.contentsOfDirectory(atPath: projectDir) else { continue }

            for file in files where file.hasSuffix(".jsonl") {
                let fullPath = "\(projectDir)/\(file)"

                guard let attrs = try? fm.attributesOfItem(atPath: fullPath),
                      let modDate = attrs[.modificationDate] as? Date,
                      let fileSize = attrs[.size] as? UInt64 else { continue }

                let age = Date().timeIntervalSince(modDate)

                // Skip files that haven't been modified recently
                guard age < activityWindow else { continue }

                // Skip files we're already tracking at this size (already reported)
                if let knownSize = trackedFiles[fullPath], knownSize == fileSize {
                    continue
                }

                // New or grown file — report it
                trackedFiles[fullPath] = fileSize
                logger.info("Detected active session: \(file) (age: \(Int(age))s, size: \(fileSize))")

                let callback = onNewSession
                let dir = projectDir
                let path = fullPath
                DispatchQueue.main.async {
                    callback(dir, path)
                }
            }
        }
    }
}
