import Foundation
import os

private let logger = Logger(subsystem: "com.personal.SeeAgents", category: "ProjectScanner")

/// Represents a running Claude Code process.
struct ClaudeProcess: Sendable {
    let pid: Int32
    let projectDirHash: String  // e.g. "-Users-name-Desktop-MyProject"
    let projectDir: String      // full path: ~/.claude/projects/<hash>
}

/// Detects active Claude Code sessions by finding running `claude` processes,
/// resolving their working directories, and matching to JSONL transcript files.
@preconcurrency
final class ProjectScanner: @unchecked Sendable {
    private let onSessionFound: @MainActor @Sendable (String, String) -> Void  // (projectDir, jsonlPath)
    private let onSessionLost: @MainActor @Sendable (String) -> Void           // jsonlPath of dead session
    private var reportedFiles: Set<String> = []
    private var knownJsonlFiles: Set<String> = []
    private var scannerStartDate: Date = .distantPast
    private var scanTimer: DispatchSourceTimer?
    private var isRunning = false

    init(
        onSessionFound: @MainActor @Sendable @escaping (String, String) -> Void,
        onSessionLost: @MainActor @Sendable @escaping (String) -> Void
    ) {
        self.onSessionFound = onSessionFound
        self.onSessionLost = onSessionLost
    }

    // MARK: - Start / Stop

    func start() {
        guard !isRunning else { return }
        isRunning = true
        scannerStartDate = Date()

        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(
            deadline: .now(),  // fire immediately
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
        knownJsonlFiles.removeAll()
    }

    func markReported(_ path: String) {
        reportedFiles.insert(path)
    }

    // MARK: - Scanning

    private func scan() {
        // Step 1: Find all running claude processes and their project dirs
        let processes = findClaudeProcesses()
        // Step 2: For each active project dir, find N most recent JSONL files
        // where N = number of claude processes in that directory
        let fm = FileManager.default
        var activeJsonlFiles = Set<String>()

        // Count processes per project dir
        var processesPerDir: [String: Int] = [:]
        for process in processes {
            processesPerDir[process.projectDir, default: 0] += 1
        }

        for (projectDir, count) in processesPerDir {
            guard fm.fileExists(atPath: projectDir) else { continue }
            guard let files = try? fm.contentsOfDirectory(atPath: projectDir) else { continue }

            // Collect all JSONL files with their modification dates.
            // Track whether each file was already known before this scan.
            var jsonlFiles: [(path: String, date: Date, wasKnown: Bool)] = []
            for file in files where file.hasSuffix(".jsonl") {
                let fullPath = "\(projectDir)/\(file)"
                if let attrs = try? fm.attributesOfItem(atPath: fullPath),
                   let modDate = attrs[.modificationDate] as? Date {
                    let wasKnown = knownJsonlFiles.contains(fullPath)
                    jsonlFiles.append((fullPath, modDate, wasKnown))
                    knownJsonlFiles.insert(fullPath)
                }
            }

            // Sort by most recent first, take N files (one per process)
            jsonlFiles.sort { $0.date > $1.date }
            let topFiles = jsonlFiles.prefix(count)

            for (jsonlPath, modDate, wasKnown) in topFiles {
                activeJsonlFiles.insert(jsonlPath)

                // Pixel-agent-like behavior:
                // - Ignore baseline files that already existed when app started.
                // - Only report JSONL files first seen after scanner start.
                if !wasKnown,
                   modDate >= scannerStartDate,
                   !reportedFiles.contains(jsonlPath) {
                    reportedFiles.insert(jsonlPath)
                    logger.info("Found active session: \(jsonlPath)")

                    let callback = onSessionFound
                    DispatchQueue.main.async {
                        callback(projectDir, jsonlPath)
                    }
                }
            }
        }

        // Step 3: Report sessions that are no longer active (process died)
        let lostFiles = reportedFiles.subtracting(activeJsonlFiles)
        for lostFile in lostFiles {
            reportedFiles.remove(lostFile)
            logger.info("Session lost (process gone): \(lostFile)")

            let callback = onSessionLost
            DispatchQueue.main.async {
                callback(lostFile)
            }
        }
    }

    // MARK: - Process Detection

    /// Find all running `claude` processes and resolve their working directories.
    /// Uses `ps` instead of `pgrep` because the actual binary name can be a version
    /// string (e.g. `2.1.71`) while `comm` shows `claude`.
    private func findClaudeProcesses() -> [ClaudeProcess] {
        guard let output = runCommand("/bin/ps", arguments: ["-eo", "pid,comm"]) else { return [] }

        // Parse ps output: "  PID COMM\n 1234 claude\n ..."
        let pids: [Int32] = output.split(separator: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.split(separator: " ", maxSplits: 1)
            guard parts.count == 2,
                  parts[1].trimmingCharacters(in: .whitespaces) == "claude",
                  let pid = Int32(parts[0]) else { return nil }
            return pid
        }

        return pids.compactMap { pid in
            guard let cwd = getProcessCwd(pid: pid) else { return nil }
            let hash = cwdToProjectHash(cwd)
            let projectDir = "\(GameConstants.claudeProjectsPath)/\(hash)"
            return ClaudeProcess(pid: pid, projectDirHash: hash, projectDir: projectDir)
        }
    }

    private func getProcessCwd(pid: Int32) -> String? {
        guard let output = runCommand("/usr/sbin/lsof", arguments: ["-a", "-p", "\(pid)", "-d", "cwd", "-Fn"]) else {
            return nil
        }

        // lsof output: "p<pid>\nfcwd\nn<path>"
        let lines = output.split(separator: "\n")
        for line in lines.reversed() {
            if line.hasPrefix("n/") {
                return String(line.dropFirst())
            }
        }
        return nil
    }

    /// Run a command and return its stdout. Reads data before waiting to prevent pipe deadlock.
    private func runCommand(_ path: String, arguments: [String]) -> String? {
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = arguments
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
        } catch {
            return nil
        }

        // IMPORTANT: read before waitUntilExit to prevent deadlock if pipe buffer fills
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()

        return String(data: data, encoding: .utf8)
    }

    /// Convert a working directory path to Claude Code's project hash format.
    /// Mirrors: `workspacePath.replace(/[^a-zA-Z0-9-]/g, '-')`
    /// e.g. `/Users/g.pulikkal/Desktop/MyProject` → `-Users-g-pulikkal-Desktop-MyProject`
    private func cwdToProjectHash(_ cwd: String) -> String {
        String(cwd.map { c in
            c.isLetter || c.isNumber || c == "-" ? c : Character("-")
        })
    }
}
