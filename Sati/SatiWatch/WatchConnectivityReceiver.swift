import Foundation
import WatchConnectivity
import Combine

final class WatchConnectivityReceiver: NSObject, ObservableObject, WCSessionDelegate {

    private var reminderManager: WatchReminderManager?
    private var topicStore: WatchTopicStore?

    @Published var isActivated = false
    @Published var lastReceivedDate: Date?

    override init() {
        super.init()
        SatiLog.info("WCRecv", "init")
    }

    func setManagers(reminderManager: WatchReminderManager, topicStore: WatchTopicStore) {
        self.reminderManager = reminderManager
        self.topicStore = topicStore
        SatiLog.info("WCRecv", "managers wired")
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
                    self.lastReceivedDate = Date()
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
        guard let reminderManager, let topicStore else {
            SatiLog.error("WCRecv", "applyContext called before managers wired")
            return
        }
        SatiLog.info("WCRecv", "applyContext — keys: \(context.keys.sorted())")

        guard let wc = WatchContextCoder.decode(context) else {
            SatiLog.error("WCRecv", "failed to decode context: \(context)")
            return
        }

        SatiLog.info("WCRecv", "applying topics=\(wc.topics) offset=\(wc.topicOffset) interval=\(wc.intervalMinutes)")
        topicStore.update(topics: wc.topics, offset: wc.topicOffset)
        reminderManager.intervalMinutes = wc.intervalMinutes
    }
}
