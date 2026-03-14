import SwiftUI

@main
struct SatiWatchApp: App {
    @StateObject private var reminderManager = WatchReminderManager()
    @StateObject private var topicStore = WatchTopicStore()
    @StateObject private var connectivity = WatchConnectivityReceiver()

    var body: some Scene {
        WindowGroup {
            WatchMainView(reminderManager: reminderManager, topicStore: topicStore, connectivity: connectivity)
                .task {
                    SatiLog.info("WatchApp", "wiring connectivity")
                    connectivity.setManagers(reminderManager: reminderManager, topicStore: topicStore)
                    connectivity.activate()
                }
        }
    }
}
