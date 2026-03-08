import Foundation
import os

private let logger = Logger(subsystem: "com.personal.SeeAgents", category: "AgentWatcher")

/// Watches a single JSONL file for new lines using DispatchSource (kqueue) + polling fallback.
/// Ported from pixel-agents `fileWatcher.ts` — `startFileWatching()` + `readNewLines()`.
///
/// Operates off the MainActor: file I/O runs on a background queue, then dispatches
/// parsed results back to MainActor for state updates.
@preconcurrency
final class AgentWatcher: @unchecked Sendable {
    private let agentId: Int
    private let jsonlFile: String
    private let onNewLines: @MainActor @Sendable (FileReadResult) -> Void
    private let watchQueue: DispatchQueue

    private var dispatchSource: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var pollingTimer: DispatchSourceTimer?
    private var isStopped = false

    // These are only accessed from the background read queue
    private var fileOffset: UInt64 = 0
    private var lineBuffer: String = ""

    struct FileReadResult: Sendable {
        let lines: [String]
        let fileOffset: UInt64
        let lineBuffer: String
    }

    init(
        agent: AgentActivity,
        onNewLines: @MainActor @Sendable @escaping (FileReadResult) -> Void
    ) {
        self.agentId = agent.id
        self.jsonlFile = agent.jsonlFile
        self.fileOffset = agent.fileOffset
        self.lineBuffer = agent.lineBuffer
        self.onNewLines = onNewLines
        self.watchQueue = DispatchQueue(label: "com.personal.SeeAgents.AgentWatcher.\(agent.id)", qos: .utility)
    }

    // MARK: - Start / Stop

    func start() {
        guard !isStopped else { return }
        logger.debug("Starting watcher for agent \(self.agentId, privacy: .public)")
        startDispatchSource()
        startPollingTimer()
        watchQueue.async { [weak self] in
            self?.readNewLines()
        }
    }

    func stop() {
        isStopped = true
        logger.debug("Stopping watcher for agent \(self.agentId, privacy: .public)")

        dispatchSource?.cancel()
        dispatchSource = nil

        pollingTimer?.cancel()
        pollingTimer = nil
    }

    // MARK: - DispatchSource (kqueue)

    private func startDispatchSource() {
        let fd = open(jsonlFile, O_RDONLY | O_EVTONLY)
        guard fd >= 0 else {
            logger.debug("kqueue open failed for agent \(self.agentId, privacy: .public), file \(self.jsonlFile, privacy: .public)")
            return
        }
        fileDescriptor = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend],
            queue: watchQueue
        )

        source.setEventHandler { [weak self] in
            self?.readNewLines()
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        dispatchSource = source
    }

    // MARK: - Polling Fallback

    private func startPollingTimer() {
        let timer = DispatchSource.makeTimerSource(queue: watchQueue)
        timer.schedule(
            deadline: .now() + GameConstants.fileWatcherPollInterval,
            repeating: GameConstants.fileWatcherPollInterval
        )
        timer.setEventHandler { [weak self] in
            self?.readNewLines()
        }
        timer.resume()
        pollingTimer = timer
    }

    // MARK: - Read New Lines (background queue)

    /// Reads new bytes from the JSONL file, splits into lines,
    /// buffers incomplete last line, and sends complete lines to MainActor callback.
    private func readNewLines() {
        guard !isStopped else { return }

        let fm = FileManager.default
        guard fm.fileExists(atPath: jsonlFile) else { return }

        guard let attrs = try? fm.attributesOfItem(atPath: jsonlFile),
              let fileSize = attrs[.size] as? UInt64 else { return }

        guard fileSize > fileOffset else { return }

        guard let handle = FileHandle(forReadingAtPath: jsonlFile) else { return }
        defer { handle.closeFile() }

        handle.seek(toFileOffset: fileOffset)
        let bytesToRead = Int(min(fileSize - fileOffset, UInt64(Int.max)))
        let newData = handle.readData(ofLength: bytesToRead)
        guard !newData.isEmpty else { return }

        fileOffset += UInt64(newData.count)

        guard let text = String(data: newData, encoding: .utf8) else { return }

        let combined = lineBuffer + text
        var splitLines = combined.components(separatedBy: "\n")
        lineBuffer = splitLines.removeLast()

        let completeLines = splitLines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard !completeLines.isEmpty else { return }

        let result = FileReadResult(
            lines: completeLines,
            fileOffset: fileOffset,
            lineBuffer: lineBuffer
        )
        let callback = onNewLines
        DispatchQueue.main.async {
            callback(result)
        }
    }
}
