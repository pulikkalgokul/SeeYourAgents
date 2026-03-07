import Foundation

/// Manages per-agent waiting and permission timers.
/// Ported from pixel-agents `timerManager.ts`.
@Observable
final class TimerManager {
    private var waitingTimers: [Int: DispatchWorkItem] = [:]
    private var permissionTimers: [Int: DispatchWorkItem] = [:]

    // MARK: - Waiting Timer (text-idle detection)

    func startWaitingTimer(for agent: AgentActivity, delay: TimeInterval) {
        cancelWaitingTimer(for: agent.id)

        let work = DispatchWorkItem { [weak self] in
            guard self != nil else { return }
            DispatchQueue.main.async {
                agent.isWaiting = true
                agent.status = .waiting
            }
        }
        waitingTimers[agent.id] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func cancelWaitingTimer(for agentId: Int) {
        waitingTimers[agentId]?.cancel()
        waitingTimers.removeValue(forKey: agentId)
    }

    // MARK: - Permission Timer

    func startPermissionTimer(for agent: AgentActivity) {
        cancelPermissionTimer(for: agent.id)

        let work = DispatchWorkItem { [weak self] in
            guard self != nil else { return }
            DispatchQueue.main.async {
                // Check if there are still non-exempt tools running
                let hasNonExempt = agent.activeToolNames.values.contains {
                    !GameConstants.permissionExemptTools.contains($0)
                }
                let hasNonExemptSubagent = agent.activeSubagentToolNames.values.contains { subMap in
                    subMap.values.contains { !GameConstants.permissionExemptTools.contains($0) }
                }

                if hasNonExempt || hasNonExemptSubagent {
                    agent.permissionSent = true
                    agent.status = .permission
                }
            }
        }
        permissionTimers[agent.id] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + GameConstants.permissionTimerDelay, execute: work)
    }

    func cancelPermissionTimer(for agentId: Int) {
        permissionTimers[agentId]?.cancel()
        permissionTimers.removeValue(forKey: agentId)
    }

    // MARK: - Cleanup

    func cancelAll(for agentId: Int) {
        cancelWaitingTimer(for: agentId)
        cancelPermissionTimer(for: agentId)
    }
}
