import Foundation
import WatchConnectivity
import Combine

final class WatchConnectivityReceiver: NSObject, ObservableObject, WCSessionDelegate {

    var reminderManager: WatchReminderManager?
    var topicStore: WatchTopicStore?

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        if activationState == .activated {
            let context = session.receivedApplicationContext
            if !context.isEmpty {
                Task { @MainActor in
                    self.applyContext(context)
                }
            }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in
            self.applyContext(applicationContext)
        }
    }

    private func applyContext(_ context: [String: Any]) {
        if let topicsData = context["topics"] as? Data,
           let topics = try? JSONDecoder().decode([String].self, from: topicsData),
           let offset = context["topicOffset"] as? Int {
            topicStore?.update(topics: topics, offset: offset)
        }
        if let interval = context["intervalMinutes"] as? Int {
            reminderManager?.intervalMinutes = interval
        }
    }
}
