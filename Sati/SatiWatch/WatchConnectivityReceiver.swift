import Foundation
import WatchConnectivity
import Combine

final class WatchConnectivityReceiver: NSObject, ObservableObject, WCSessionDelegate {

    let reminderManager: WatchReminderManager
    let topicStore: WatchTopicStore

    @Published var isActivated = false
    @Published var lastReceivedDate: Date?

    init(reminderManager: WatchReminderManager, topicStore: WatchTopicStore) {
        self.reminderManager = reminderManager
        self.topicStore = topicStore
        super.init()
        SatiLog.info("WCRecv", "init with reminderManager and topicStore")
    }

    func activate() {
        guard WCSession.isSupported() else {
            SatiLog.error("WCRecv", "WCSession not supported")
            return
        }
        let session = WCSession.default
        session.delegate = self
        SatiLog.info("WCRecv", "activating session")
        session.activate()
    }

    func requestSync() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else {
            SatiLog.warning("WCRecv", "requestSync failed: not activated or not reachable")
            return
        }

        let message = ["action": "requestSync"]
        session.sendMessage(message, replyHandler: { reply in
            SatiLog.info("WCRecv", "sync request reply: \(reply)")
        }, errorHandler: { error in
            SatiLog.error("WCRecv", "sync request error: \(error)")
        })
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        SatiLog.info("WCRecv", "activationDidComplete: state=\(activationState.rawValue) error=\(String(describing: error))")
        Task { @MainActor in
            self.isActivated = (activationState == .activated)
        }
        if activationState == .activated {
            let context = session.receivedApplicationContext
            SatiLog.info("WCRecv", "existing context keys: \(context.keys.sorted())")
            if !context.isEmpty {
                Task { @MainActor in
                    self.applyContext(context)
                }
            } else {
                SatiLog.info("WCRecv", "no existing context found")
            }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        SatiLog.info("WCRecv", "didReceiveApplicationContext keys: \(applicationContext.keys.sorted())")
        Task { @MainActor in
            self.applyContext(applicationContext)
            self.lastReceivedDate = Date()
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        SatiLog.info("WCRecv", "didReceiveMessage: \(message)")
    }

    private func applyContext(_ context: [String: Any]) {
        SatiLog.info("WCRecv", "applyContext — keys: \(context.keys.sorted())")

        var decodedTopics: [String]?
        if let topicsData = context["topics"] as? Data {
            decodedTopics = try? JSONDecoder().decode([String].self, from: topicsData)
            SatiLog.info("WCRecv", "decoded topics from Data: \(decodedTopics ?? [])")
        } else if let topicsArray = context["topics"] as? [String] {
            decodedTopics = topicsArray
            SatiLog.info("WCRecv", "received topics as array: \(topicsArray)")
        } else {
            SatiLog.error("WCRecv", "topics not Data or [String]: \(String(describing: type(of: context["topics"])))")
        }

        if let topics = decodedTopics, let offset = context["topicOffset"] as? Int {
            SatiLog.info("WCRecv", "applying topics=\(topics) offset=\(offset)")
            topicStore.update(topics: topics, offset: offset)
        } else {
            SatiLog.error("WCRecv", "failed to decode — topics=\(String(describing: context["topics"])) offset=\(String(describing: context["topicOffset"]))")
        }

        if let interval = context["intervalMinutes"] as? Int {
            SatiLog.info("WCRecv", "applying interval=\(interval)")
            reminderManager.intervalMinutes = interval
        } else {
            SatiLog.error("WCRecv", "failed to get interval: \(String(describing: context["intervalMinutes"]))")
        }
    }
}
