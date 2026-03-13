import SwiftUI

@main
struct SatiWatchApp: App {
    @StateObject private var reminderManager: WatchReminderManager
    @StateObject private var topicStore: WatchTopicStore
    @StateObject private var connectivity: WatchConnectivityReceiver

    init() {
        let rm = WatchReminderManager()
        let ts = WatchTopicStore()
        let conn = WatchConnectivityReceiver(reminderManager: rm, topicStore: ts)

        _reminderManager = StateObject(wrappedValue: rm)
        _topicStore = StateObject(wrappedValue: ts)
        _connectivity = StateObject(wrappedValue: conn)

        SatiLog.info("WatchApp", "init complete, activating connectivity")
        conn.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchMainView(reminderManager: reminderManager, topicStore: topicStore)
        }
    }
}
