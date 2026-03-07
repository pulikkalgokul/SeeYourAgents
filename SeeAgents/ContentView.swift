import SwiftUI

struct ContentView: View {
    var agentManager: AgentManager

    var body: some View {
        NavigationSplitView {
            List {
                if agentManager.sortedAgents.isEmpty {
                    ContentUnavailableView {
                        Label("No Agents Detected", systemImage: "person.crop.circle.badge.questionmark")
                    } description: {
                        Text("Start a Claude Code session in your terminal and it will appear here automatically.")
                    }
                } else {
                    ForEach(agentManager.sortedAgents) { agent in
                        NavigationLink(value: agent.id) {
                            AgentRow(agent: agent)
                        }
                    }
                }
            }
            .navigationTitle("SeeAgents")
        } detail: {
            NavigationStack {
                if let selectedAgent = agentManager.sortedAgents.first {
                    AgentDetailView(agent: selectedAgent)
                } else {
                    ContentUnavailableView(
                        "Select an Agent",
                        systemImage: "person.crop.circle"
                    )
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

// MARK: - Agent Row

struct AgentRow: View {
    var agent: AgentActivity

    var body: some View {
        HStack(spacing: 10) {
            StatusIndicator(status: agent.status)

            VStack(alignment: .leading, spacing: 2) {
                Text("Agent #\(agent.id)")
                    .font(.headline)

                Text(agent.projectName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let toolStatus = agent.currentToolStatus {
                    Text(toolStatus)
                        .font(.caption2)
                        .foregroundStyle(statusColor(for: agent.status))
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func statusColor(for status: AgentStatus) -> Color {
        switch status {
        case .active: .green
        case .waiting: .blue
        case .permission: .orange
        }
    }
}

// MARK: - Status Indicator

struct StatusIndicator: View {
    var status: AgentStatus

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
    }

    private var color: Color {
        switch status {
        case .active: .green
        case .waiting: .blue
        case .permission: .orange
        }
    }
}

// MARK: - Agent Detail View

struct AgentDetailView: View {
    var agent: AgentActivity

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                StatusIndicator(status: agent.status)
                Text("Agent #\(agent.id)")
                    .font(.title2.bold())
                Spacer()
                Text(agent.status.rawValue.capitalized)
                    .font(.callout)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusBackground)
                    .clipShape(Capsule())
            }

            Divider()

            // Info grid
            LabeledContent("Project") {
                Text(agent.projectName)
            }
            LabeledContent("Session") {
                Text(agent.sessionId)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
            LabeledContent("JSONL File") {
                Text(agent.jsonlFile)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .lineLimit(2)
            }

            Divider()

            // Active tools
            Text("Active Tools")
                .font(.headline)

            if agent.activeToolIds.isEmpty {
                Text("No active tools")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(agent.activeToolIds), id: \.self) { toolId in
                    HStack {
                        Image(systemName: toolIcon(for: agent.activeToolNames[toolId]))
                        Text(agent.activeToolStatuses[toolId] ?? toolId)
                    }
                    .font(.callout)
                }
            }

            // Sub-agent tools
            if !agent.activeSubagentToolNames.isEmpty {
                Divider()
                Text("Sub-agent Tools")
                    .font(.headline)

                ForEach(Array(agent.activeSubagentToolNames.keys), id: \.self) { parentId in
                    if let subTools = agent.activeSubagentToolNames[parentId] {
                        ForEach(Array(subTools), id: \.key) { subId, name in
                            HStack {
                                Image(systemName: "arrow.turn.down.right")
                                Text(name)
                            }
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Agent #\(agent.id)")
    }

    private var statusBackground: Color {
        switch agent.status {
        case .active: .green.opacity(0.2)
        case .waiting: .blue.opacity(0.2)
        case .permission: .orange.opacity(0.2)
        }
    }

    private func toolIcon(for toolName: String?) -> String {
        switch toolName {
        case "Read": "doc.text"
        case "Edit", "Write": "pencil"
        case "Bash": "terminal"
        case "Glob": "magnifyingglass"
        case "Grep": "text.magnifyingglass"
        case "WebFetch", "WebSearch": "globe"
        case "Task": "person.2"
        default: "wrench"
        }
    }
}
