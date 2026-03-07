import Foundation

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

    private var dispatchSource: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var pollingTimer: DispatchSourceTimer?
    private var isStopped = false

    // These are only accessed from the background read queue
    private var fileOffset: UInt64 = 0
    private var lineBuffer: String = ""

    struct FileReadResult: Sendable {
        let lines: [String]
        let hasActivity: Bool
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
    }

    // MARK: - Start / Stop

    func start() {
        guard !isStopped else { return }
        startDispatchSource()
        startPollingTimer()
        readNewLines()
    }

    func stop() {
        isStopped = true

        dispatchSource?.cancel()
        dispatchSource = nil

        pollingTimer?.cancel()
        pollingTimer = nil
    }

    // MARK: - DispatchSource (kqueue)

    private func startDispatchSource() {
        let fd = open(jsonlFile, O_RDONLY | O_EVTONLY)
        guard fd >= 0 else { return }
        fileDescriptor = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend],
            queue: .global(qos: .utility)
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
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
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
        let newData = handle.readData(ofLength: Int(fileSize - fileOffset))
        guard !newData.isEmpty else { return }

        fileOffset += UInt64(newData.count)

        guard let text = String(data: newData, encoding: .utf8) else { return }

        let combined = lineBuffer + text
        var splitLines = combined.components(separatedBy: "\n")
        lineBuffer = splitLines.removeLast()

        let completeLines = splitLines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let hasActivity = !completeLines.isEmpty

        guard hasActivity else { return }

        let result = FileReadResult(lines: completeLines, hasActivity: hasActivity)
        let callback = onNewLines
        DispatchQueue.main.async {
            callback(result)
        }
    }
}
