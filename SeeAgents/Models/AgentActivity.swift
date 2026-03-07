import Foundation
import SwiftUI

/// Runtime state for a single detected Claude Code agent session.
@Observable
final class AgentActivity: Identifiable {
    let id: Int
    let projectDir: String
    var jsonlFile: String
    var fileOffset: UInt64 = 0
    var lineBuffer: String = ""

    // Tool tracking
    var activeToolIds: Set<String> = []
    var activeToolStatuses: [String: String] = [:]  // toolId -> status label
    var activeToolNames: [String: String] = [:]     // toolId -> tool name
    var activeSubagentToolIds: [String: Set<String>] = [:]         // parentToolId -> sub-tool IDs
    var activeSubagentToolNames: [String: [String: String]] = [:]  // parentToolId -> (subToolId -> name)

    // State
    var isWaiting: Bool = false
    var permissionSent: Bool = false
    var hadToolsInTurn: Bool = false
    var status: AgentStatus = .active

    /// Timestamp of last received data from the watcher.
    var lastDataReceived: Date

    init(id: Int, projectDir: String, jsonlFile: String) {
        self.id = id
        self.projectDir = projectDir
        self.jsonlFile = jsonlFile
        self.lastDataReceived = Date()
    }

    /// Human-readable summary of current activity.
    var currentToolStatus: String? {
        if isWaiting { return "Waiting for input" }
        if permissionSent { return "Needs permission" }
        if let firstToolId = activeToolIds.first,
           let status = activeToolStatuses[firstToolId] {
            return status
        }
        return nil
    }

    /// The project name derived from the project directory path.
    var projectName: String {
        // ~/.claude/projects/Users-name-Desktop-MyProject -> MyProject
        let components = projectDir.split(separator: "/")
        guard let last = components.last else { return "Unknown" }
        let parts = last.split(separator: "-")
        return parts.last.map(String.init) ?? String(last)
    }

    /// Session ID extracted from the JSONL filename.
    var sessionId: String {
        URL(fileURLWithPath: jsonlFile).deletingPathExtension().lastPathComponent
    }
}

enum AgentStatus: String {
    case active
    case waiting
    case permission

    var color: Color {
        switch self {
        case .active: .green
        case .waiting: .blue
        case .permission: .orange
        }
    }
}
