import Foundation

/// Parses JSONL transcript lines and updates agent state accordingly.
/// Ported from pixel-agents `transcriptParser.ts`.
enum TranscriptParser {

    /// Format a tool invocation into a human-readable status label.
    static func formatToolStatus(toolName: String, input: [String: AnyCodable]?) -> String {
        switch toolName {
        case "Read", "Edit", "Write":
            if let path = input?["file_path"]?.stringValue {
                let basename = URL(fileURLWithPath: path).lastPathComponent
                let verb = toolName == "Read" ? "Reading" : toolName == "Edit" ? "Editing" : "Writing"
                return "\(verb) \(basename)"
            }
            return "\(toolName)ing file"

        case "Bash":
            if let cmd = input?["command"]?.stringValue {
                let truncated = cmd.count > GameConstants.bashCommandDisplayMaxLength
                    ? String(cmd.prefix(GameConstants.bashCommandDisplayMaxLength)) + "..."
                    : cmd
                return "Running: \(truncated)"
            }
            return "Running command"

        case "Glob":
            return "Searching files"
        case "Grep":
            return "Searching content"
        case "WebFetch":
            return "Fetching web page"
        case "WebSearch":
            return "Searching web"
        case "Task":
            if let desc = input?["description"]?.stringValue {
                let truncated = desc.count > GameConstants.taskDescriptionDisplayMaxLength
                    ? String(desc.prefix(GameConstants.taskDescriptionDisplayMaxLength)) + "..."
                    : desc
                return "Subtask: \(truncated)"
            }
            return "Running subtask"
        case "AskUserQuestion":
            return "Waiting for your answer"
        case "EnterPlanMode":
            return "Planning"
        case "NotebookEdit":
            return "Editing notebook"
        default:
            return "Using \(toolName)"
        }
    }

    /// Process a single JSONL transcript line and update the agent's state.
    static func processLine(
        _ line: String,
        agent: AgentActivity,
        timerManager: TimerManager
    ) {
        guard !line.isEmpty else { return }

        guard let data = line.data(using: .utf8),
              let record = try? JSONDecoder().decode(TranscriptRecord.self, from: data) else {
            return
        }

        switch record.type {
        case "assistant":
            handleAssistant(record: record, agent: agent, timerManager: timerManager)
        case "user":
            handleUser(record: record, agent: agent, timerManager: timerManager)
        case "system":
            handleSystem(record: record, agent: agent, timerManager: timerManager)
        case "progress":
            handleProgress(record: record, agent: agent, timerManager: timerManager)
        default:
            break
        }
    }

    // MARK: - Record Type Handlers

    private static func handleAssistant(
        record: TranscriptRecord,
        agent: AgentActivity,
        timerManager: TimerManager
    ) {
        guard let content = record.message?.content else { return }
        let blocks = content.blocks
        let toolUseBlocks = blocks.filter { $0.type == "tool_use" }

        if !toolUseBlocks.isEmpty {
            // Tool-using turn
            timerManager.cancelWaitingTimer(for: agent.id)
            agent.isWaiting = false
            agent.hadToolsInTurn = true
            agent.status = .active

            var hasNonExempt = false

            for block in toolUseBlocks {
                guard let toolId = block.id, let toolName = block.name else { continue }
                let status = formatToolStatus(toolName: toolName, input: block.input)

                agent.activeToolIds.insert(toolId)
                agent.activeToolStatuses[toolId] = status
                agent.activeToolNames[toolId] = toolName

                if !GameConstants.permissionExemptTools.contains(toolName) {
                    hasNonExempt = true
                }
            }

            if hasNonExempt {
                timerManager.startPermissionTimer(for: agent)
            }
        } else if !agent.hadToolsInTurn {
            // Text-only turn — start idle timer
            timerManager.startWaitingTimer(
                for: agent,
                delay: GameConstants.textIdleDelay
            )
        }
    }

    private static func handleUser(
        record: TranscriptRecord,
        agent: AgentActivity,
        timerManager: TimerManager
    ) {
        guard let content = record.message?.content else { return }

        switch content {
        case .blocks(let blocks):
            let toolResults = blocks.filter { $0.type == "tool_result" }
            if !toolResults.isEmpty {
                for result in toolResults {
                    guard let toolUseId = result.toolUseId else { continue }

                    // Check if parent is a Task tool — clear subagent tracking
                    if agent.activeToolNames[toolUseId] == "Task" {
                        agent.activeSubagentToolIds.removeValue(forKey: toolUseId)
                        agent.activeSubagentToolNames.removeValue(forKey: toolUseId)
                    }

                    agent.activeToolIds.remove(toolUseId)
                    agent.activeToolStatuses.removeValue(forKey: toolUseId)
                    agent.activeToolNames.removeValue(forKey: toolUseId)
                }

                if agent.activeToolIds.isEmpty {
                    agent.hadToolsInTurn = false
                }
            } else {
                // New text prompt — reset
                timerManager.cancelWaitingTimer(for: agent.id)
                clearActivity(agent: agent, timerManager: timerManager)
                agent.hadToolsInTurn = false
            }

        case .string:
            // New text prompt
            timerManager.cancelWaitingTimer(for: agent.id)
            clearActivity(agent: agent, timerManager: timerManager)
            agent.hadToolsInTurn = false
        }
    }

    private static func handleSystem(
        record: TranscriptRecord,
        agent: AgentActivity,
        timerManager: TimerManager
    ) {
        guard record.subtype == "turn_duration" else { return }

        // Definitive turn-end signal
        timerManager.cancelWaitingTimer(for: agent.id)
        timerManager.cancelPermissionTimer(for: agent.id)

        // Clear all stale tool state
        agent.activeToolIds.removeAll()
        agent.activeToolStatuses.removeAll()
        agent.activeToolNames.removeAll()
        agent.activeSubagentToolIds.removeAll()
        agent.activeSubagentToolNames.removeAll()

        agent.isWaiting = true
        agent.permissionSent = false
        agent.hadToolsInTurn = false
        agent.status = .waiting
    }

    private static func handleProgress(
        record: TranscriptRecord,
        agent: AgentActivity,
        timerManager: TimerManager
    ) {
        guard let parentToolId = record.parentToolUseID,
              let data = record.data else { return }

        switch data.type {
        case "bash_progress", "mcp_progress":
            // Tool is actively executing — restart permission timer
            if agent.activeToolIds.contains(parentToolId) {
                timerManager.startPermissionTimer(for: agent)
            }

        case "agent_progress":
            // Sub-agent activity within a Task tool
            guard let message = data.message,
                  let content = message.content else { return }

            if message.role == "assistant" {
                let toolBlocks = content.blocks.filter { $0.type == "tool_use" }
                for block in toolBlocks {
                    guard let subToolId = block.id, let toolName = block.name else { continue }

                    var subIds = agent.activeSubagentToolIds[parentToolId] ?? []
                    subIds.insert(subToolId)
                    agent.activeSubagentToolIds[parentToolId] = subIds

                    var subNames = agent.activeSubagentToolNames[parentToolId] ?? [:]
                    subNames[subToolId] = toolName
                    agent.activeSubagentToolNames[parentToolId] = subNames

                    if !GameConstants.permissionExemptTools.contains(toolName) {
                        timerManager.startPermissionTimer(for: agent)
                    }
                }
            } else if message.role == "user" {
                let results = content.blocks.filter { $0.type == "tool_result" }
                for result in results {
                    guard let subToolId = result.toolUseId else { continue }
                    agent.activeSubagentToolIds[parentToolId]?.remove(subToolId)
                    agent.activeSubagentToolNames[parentToolId]?.removeValue(forKey: subToolId)
                }
            }

        default:
            break
        }
    }

    // MARK: - Helpers

    static func clearActivity(agent: AgentActivity, timerManager: TimerManager) {
        agent.activeToolIds.removeAll()
        agent.activeToolStatuses.removeAll()
        agent.activeToolNames.removeAll()
        agent.activeSubagentToolIds.removeAll()
        agent.activeSubagentToolNames.removeAll()
        agent.isWaiting = false
        agent.permissionSent = false
        timerManager.cancelPermissionTimer(for: agent.id)
        agent.status = .active
    }
}
