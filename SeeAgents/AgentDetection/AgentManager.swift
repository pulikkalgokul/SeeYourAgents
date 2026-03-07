import Foundation
import os

private let logger = Logger(subsystem: "com.personal.SeeAgents", category: "AgentManager")

/// Orchestrates agent detection: scans for JSONL files and manages per-agent watchers.
/// Ported from pixel-agents `agentManager.ts`.
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

        logger.info("Starting project scanner at \(GameConstants.claudeProjectsPath)")

        let scanner = ProjectScanner { [weak self] projectDir, jsonlPath in
            guard let self else { return }
            logger.info("Scanner found session: \(jsonlPath)")
            self.addAgent(projectDir: projectDir, jsonlFile: jsonlPath)
        }
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
        // Don't add duplicates
        guard !agents.values.contains(where: { $0.jsonlFile == jsonlFile }) else {
            logger.debug("Skipping duplicate: \(jsonlFile)")
            return
        }

        let id = nextAgentId
        nextAgentId += 1

        let agent = AgentActivity(id: id, projectDir: projectDir, jsonlFile: jsonlFile)
        agents[id] = agent

        logger.info("Added agent #\(id) for \(jsonlFile)")

        let watcher = AgentWatcher(agent: agent) { [weak self] result in
            guard let self, let agent = self.agents[id] else { return }

            if result.hasActivity {
                self.timerManager.cancelWaitingTimer(for: agent.id)
                self.timerManager.cancelPermissionTimer(for: agent.id)

                if agent.permissionSent {
                    agent.permissionSent = false
                    agent.status = .active
                }
            }

            for line in result.lines {
                TranscriptParser.processLine(line, agent: agent, timerManager: self.timerManager)
            }
        }
        watchers[id] = watcher
        scanner?.markTracked(jsonlFile)
        watcher.start()
    }

    func removeAgent(_ agentId: Int) {
        watchers[agentId]?.stop()
        watchers.removeValue(forKey: agentId)
        timerManager.cancelAll(for: agentId)
        agents.removeValue(forKey: agentId)
    }

}
