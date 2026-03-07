import SwiftUI

@main
struct SeeAgentsApp: App {
    @State private var agentManager = AgentManager()

    var body: some Scene {
        WindowGroup {
            ContentView(agentManager: agentManager)
                .onAppear {
                    agentManager.startScanning()
                }
        }
    }
}
