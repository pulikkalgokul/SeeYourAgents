import Foundation

final class AgentBridge {
    private weak var agentManager: AgentManager?
    private let officeState: OfficeState

    private var knownAgentIds = Set<Int>()
    private var lastActiveByAgent: [Int: Bool] = [:]
    private var lastToolByAgent: [Int: String?] = [:]
    private var lastPermissionByAgent: [Int: Bool] = [:]
    private var lastWaitingByAgent: [Int: Bool] = [:]

    init(agentManager: AgentManager, officeState: OfficeState) {
        self.agentManager = agentManager
        self.officeState = officeState
    }

    func sync() {
        guard let manager = agentManager else { return }

        let currentAgents = manager.agents
        let currentIds = Set(currentAgents.keys)

        // New agents
        let newIds = currentIds.subtracting(knownAgentIds)
        for id in newIds {
            officeState.addAgent(id: id)
            knownAgentIds.insert(id)
        }

        // Removed agents
        let removedIds = knownAgentIds.subtracting(currentIds)
        for id in removedIds {
            officeState.removeAgent(id: id)
            knownAgentIds.remove(id)
            lastActiveByAgent.removeValue(forKey: id)
            lastToolByAgent.removeValue(forKey: id)
            lastPermissionByAgent.removeValue(forKey: id)
            lastWaitingByAgent.removeValue(forKey: id)
        }

        // Update existing agents
        for (id, agent) in currentAgents {
            let isActive = !agent.activeToolIds.isEmpty ||
                agent.status == .active ||
                agent.status == .thinking

            if lastActiveByAgent[id] != isActive {
                officeState.setAgentActive(id: id, active: isActive)
                lastActiveByAgent[id] = isActive
            }

            let currentTool: String? = agent.activeToolIds.first.flatMap { agent.activeToolNames[$0] }
            if lastToolByAgent[id] as? String != currentTool {
                officeState.setAgentTool(id: id, tool: currentTool)
                lastToolByAgent[id] = currentTool
            }

            let hasPermission = agent.permissionSent
            if lastPermissionByAgent[id] != hasPermission {
                if hasPermission {
                    officeState.showPermissionBubble(id: id)
                } else {
                    officeState.clearPermissionBubble(id: id)
                }
                lastPermissionByAgent[id] = hasPermission
            }

            let isWaiting = agent.isWaiting
            if lastWaitingByAgent[id] != isWaiting {
                if isWaiting {
                    officeState.showWaitingBubble(id: id)
                }
                lastWaitingByAgent[id] = isWaiting
            }
        }
    }
}
