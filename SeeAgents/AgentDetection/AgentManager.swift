import Foundation
import os

private let logger = Logger(subsystem: "com.personal.SeeAgents", category: "AgentManager")

/// Orchestrates agent detection: finds running claude processes and watches their JSONL files.
@Observable
final class AgentManager {
    private(set) var agents: [Int: AgentActivity] = [:]
    let timerManager = TimerManager()

    private var nextAgentId = 1
    private var watchers: [Int: AgentWatcher] = [:]
    private var scanner: ProjectScanner?

    /// Sorted list of agents for UI display.
    var sortedAgents: [AgentActivity] {
        agents.values.sorted { $0.id < $1.id }
    }

    // MARK: - Lifecycle

    func startScanning() {
        guard scanner == nil else { return }

        logger.info("Starting process-based scanner")

        let scanner = ProjectScanner(
            onSessionFound: { [weak self] projectDir, jsonlPath in
                guard let self else { return }
                self.addAgent(projectDir: projectDir, jsonlFile: jsonlPath)
            },
            onSessionLost: { [weak self] jsonlPath in
                guard let self else { return }
                self.removeAgentByFile(jsonlPath)
            }
        )
        self.scanner = scanner
        scanner.start()
    }

    func stopScanning() {
        scanner?.stop()
        scanner = nil

        for (_, watcher) in watchers {
            watcher.stop()
        }
        watchers.removeAll()
    }

    // MARK: - Agent Management

    private func addAgent(projectDir: String, jsonlFile: String) {
        guard !agents.values.contains(where: { $0.jsonlFile == jsonlFile }) else { return }

        let id = nextAgentId
        nextAgentId += 1

        let agent = AgentActivity(id: id, projectDir: projectDir, jsonlFile: jsonlFile)
        agents[id] = agent

        logger.info("Added agent #\(id) for \(jsonlFile)")

        let watcher = AgentWatcher(agent: agent) { [weak self] result in
            guard let self, let agent = self.agents[id] else { return }

            agent.lastDataReceived = Date()

            self.timerManager.cancelWaitingTimer(for: agent.id)
            self.timerManager.cancelPermissionTimer(for: agent.id)

            if agent.permissionSent {
                agent.permissionSent = false
                agent.status = .active
            }

            for line in result.lines {
                TranscriptParser.processLine(line, agent: agent, timerManager: self.timerManager)
            }
        }
        watchers[id] = watcher
        scanner?.markReported(jsonlFile)
        watcher.start()
    }

    func removeAgent(_ agentId: Int) {
        watchers[agentId]?.stop()
        watchers.removeValue(forKey: agentId)
        timerManager.cancelAll(for: agentId)
        agents.removeValue(forKey: agentId)
        logger.info("Removed agent #\(agentId)")
    }

    /// Remove agent by its JSONL file path (called when process dies).
    private func removeAgentByFile(_ jsonlPath: String) {
        guard let (id, _) = agents.first(where: { $0.value.jsonlFile == jsonlPath }) else { return }
        removeAgent(id)
    }
}
