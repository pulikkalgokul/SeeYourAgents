import SwiftUI

struct ContentView: View {
    var agentManager: AgentManager
    @State private var selectedAgentId: Int?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedAgentId) {
                if agentManager.sortedAgents.isEmpty {
                    ContentUnavailableView {
                        Label("No Agents Detected", systemImage: "person.crop.circle.badge.questionmark")
                    } description: {
                        Text("Start a Claude Code session in your terminal and it will appear here automatically.")
                    }
                } else {
                    ForEach(agentManager.sortedAgents) { agent in
                        AgentRow(agent: agent)
                            .tag(agent.id)
                    }
                }
            }
            .navigationTitle("SeeAgents")
        } detail: {
            if let id = selectedAgentId, let agent = agentManager.agents[id] {
                AgentDetailView(agent: agent)
            } else {
                ContentUnavailableView(
                    "Select an Agent",
                    systemImage: "person.crop.circle"
                )
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
                        .foregroundStyle(agent.status.color)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Status Indicator

struct StatusIndicator: View {
    var status: AgentStatus

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: 10, height: 10)
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
                    .background(agent.status.color.opacity(0.2))
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
