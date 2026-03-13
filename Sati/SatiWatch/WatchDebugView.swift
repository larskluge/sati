import SwiftUI
import WatchConnectivity

/// Debug view to test Watch Connectivity sync
/// Add this to your watch app to diagnose sync issues
struct WatchDebugView: View {
    @ObservedObject var connectivity: WatchConnectivityReceiver
    @ObservedObject var topicStore: WatchTopicStore
    @ObservedObject var reminderManager: WatchReminderManager
    
    var body: some View {
        List {
            Section("Connectivity Status") {
                statusRow("Activated", connectivity.isActivated ? "✓" : "✗")
                
                if WCSession.isSupported() {
                    let session = WCSession.default
                    statusRow("Paired", session.isPaired ? "✓" : "✗")
                    statusRow("Reachable", session.isReachable ? "✓" : "✗")
                    statusRow("Companion Installed", session.isCompanionAppInstalled ? "✓" : "✗")
                } else {
                    Text("WCSession not supported")
                        .foregroundColor(.red)
                }
                
                if let lastReceived = connectivity.lastReceivedDate {
                    Text("Last sync: \(lastReceived, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Never synced")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Section("Current Data") {
                Text("Topics: \(topicStore.topics.count)")
                if !topicStore.topics.isEmpty {
                    ForEach(topicStore.topics, id: \.self) { topic in
                        Text("• \(topic)")
                            .font(.caption)
                    }
                }
                Text("Offset: \(topicStore.offset)")
                Text("Interval: \(reminderManager.intervalMinutes) min")
            }
            
            Section("Actions") {
                Button("Request Sync") {
                    print("[WatchDebugView] Manual sync requested")
                    connectivity.requestSync()
                }
                
                Button("Print Status") {
                    printDebugStatus()
                }
            }
        }
        .navigationTitle("Debug")
    }
    
    private func statusRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(value == "✓" ? .green : .red)
        }
    }
    
    private func printDebugStatus() {
        print("=== WATCH DEBUG STATUS ===")
        print("Topics: \(topicStore.topics)")
        print("Offset: \(topicStore.offset)")
        print("Interval: \(reminderManager.intervalMinutes)")
        print("Activated: \(connectivity.isActivated)")
        
        if WCSession.isSupported() {
            let session = WCSession.default
            print("Session state: \(session.activationState.rawValue)")
            print("isPaired: \(session.isPaired)")
            print("isReachable: \(session.isReachable)")
            print("isCompanionAppInstalled: \(session.isCompanionAppInstalled)")
            print("Received context: \(session.receivedApplicationContext)")
        }
        print("========================")
    }
}
