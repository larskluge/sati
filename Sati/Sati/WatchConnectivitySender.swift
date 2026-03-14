#if os(iOS)
import Foundation
import WatchConnectivity
import Combine

final class WatchConnectivitySender: NSObject, ObservableObject, WCSessionDelegate {

    @Published var isPaired: Bool = false
    @Published var isWatchAppInstalled: Bool = false
    @Published var lastSyncDate: Date?

    private let topicManager: TopicManager
    private let reminderManager: ReminderManager
    private var cancellables = Set<AnyCancellable>()
    private var debounceTimer: Timer?

    init(topicManager: TopicManager, reminderManager: ReminderManager) {
        self.topicManager = topicManager
        self.reminderManager = reminderManager
        super.init()

        guard WCSession.isSupported() else {
            SatiLog.error("WCSender", "WCSession not supported")
            return
        }
        let session = WCSession.default
        session.delegate = self
        SatiLog.info("WCSender", "activating session, isPaired=\(session.isPaired), isWatchAppInstalled=\(session.isWatchAppInstalled)")
        session.activate()

        topicManager.$topics
            .sink { [weak self] _ in self?.scheduleSync() }
            .store(in: &cancellables)

        topicManager.$offset
            .sink { [weak self] _ in self?.scheduleSync() }
            .store(in: &cancellables)

        reminderManager.$intervalMinutes
            .sink { [weak self] _ in self?.scheduleSync() }
            .store(in: &cancellables)
    }

    private func scheduleSync() {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.sendContext()
        }
    }

    private func sendContext() {
        let session = WCSession.default
        SatiLog.info("WCSender", "sendContext: activationState=\(session.activationState.rawValue) isPaired=\(session.isPaired) isWatchAppInstalled=\(session.isWatchAppInstalled)")
        guard session.activationState == .activated else {
            SatiLog.warning("WCSender", "skipping — not activated")
            return
        }

        guard session.isPaired else {
            SatiLog.warning("WCSender", "skipping — watch not paired")
            return
        }

        let wc = WatchContext(topics: topicManager.topics, topicOffset: topicManager.offset, intervalMinutes: reminderManager.intervalMinutes)
        guard let context = WatchContextCoder.encode(wc) else {
            SatiLog.error("WCSender", "failed to encode context")
            return
        }

        do {
            try session.updateApplicationContext(context)
            lastSyncDate = Date()
            SatiLog.info("WCSender", "sent context: interval=\(reminderManager.intervalMinutes) offset=\(topicManager.offset) topics=\(topicManager.topics)")
        } catch {
            SatiLog.error("WCSender", "updateApplicationContext failed: \(error)")
        }
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        SatiLog.info("WCSender", "activationDidComplete: state=\(activationState.rawValue) error=\(String(describing: error))")
        Task { @MainActor in
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            if activationState == .activated {
                self.sendContext()
            }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        SatiLog.info("WCSender", "didReceiveMessage: \(message)")
        if message["action"] as? String == "requestSync" {
            Task { @MainActor in
                self.sendContext()
                replyHandler(["status": "synced"])
            }
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        SatiLog.info("WCSender", "watchStateDidChange: isPaired=\(session.isPaired) isWatchAppInstalled=\(session.isWatchAppInstalled)")
        Task { @MainActor in
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            if session.isPaired && session.isWatchAppInstalled {
                self.sendContext()
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        SatiLog.info("WCSender", "sessionDidBecomeInactive")
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        SatiLog.info("WCSender", "sessionDidDeactivate — reactivating")
        session.activate()
    }
}
#endif
