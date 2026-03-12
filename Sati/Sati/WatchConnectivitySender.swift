#if os(iOS)
import Foundation
import WatchConnectivity
import Combine

final class WatchConnectivitySender: NSObject, ObservableObject, WCSessionDelegate {

    private let topicManager: TopicManager
    private let reminderManager: ReminderManager
    private var cancellables = Set<AnyCancellable>()
    private var debounceTimer: Timer?

    init(topicManager: TopicManager, reminderManager: ReminderManager) {
        self.topicManager = topicManager
        self.reminderManager = reminderManager
        super.init()

        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()

        topicManager.$topics
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
        guard WCSession.default.activationState == .activated else { return }

        var context: [String: Any] = [
            "intervalMinutes": reminderManager.intervalMinutes,
            "topicOffset": topicManager.offset,
        ]
        if let data = try? JSONEncoder().encode(topicManager.topics) {
            context["topics"] = data
        }

        try? WCSession.default.updateApplicationContext(context)
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        if activationState == .activated {
            Task { @MainActor in
                self.sendContext()
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
#endif
