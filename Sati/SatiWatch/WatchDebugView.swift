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
                HStack {
                    Text("Activated")
                    Spacer()
                    Text(connectivity.isActivated ? "✓" : "✗")
                        .foregroundColor(connectivity.isActivated ? .green : .red)
                }
                
                if WCSession.isSupported() {
                    connectivityStatusRows
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
    
    @ViewBuilder
    private var connectivityStatusRows: some View {
        let session = WCSession.default
        
        HStack {
            Text("Reachable")
            Spacer()
            Text(session.isReachable ? "✓" : "✗")
                .foregroundColor(session.isReachable ? .green : .red)
        }
        
        HStack {
            Text("Companion Installed")
            Spacer()
            Text(session.isCompanionAppInstalled ? "✓" : "✗")
                .foregroundColor(session.isCompanionAppInstalled ? .green : .red)
        }
        
        HStack {
            Text("State")
            Spacer()
            Text(activationStateText)
                .foregroundColor(session.activationState == .activated ? .green : .orange)
        }
    }
    
    private var activationStateText: String {
        let session = WCSession.default
        switch session.activationState {
        case .notActivated: return "Not Activated"
        case .inactive: return "Inactive"
        case .activated: return "Activated"
        @unknown default: return "Unknown"
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
            print("isReachable: \(session.isReachable)")
            print("isCompanionAppInstalled: \(session.isCompanionAppInstalled)")
            print("Received context: \(session.receivedApplicationContext)")
        }
        print("========================")
    }
}
