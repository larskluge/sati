import Foundation
import WatchKit
import Combine

final class WatchReminderManager: NSObject, ObservableObject, WKExtendedRuntimeSessionDelegate {

    @Published var isActive: Bool = true
    @Published var snoozeUntil: Date?
    @Published var lastReminderDate: Date = Date()
    @Published var lastReminderPhrase: String?
    @Published var hapticType: WKHapticType = .notification

    @Published var intervalMinutes: Int {
        didSet {
            UserDefaults.standard.set(intervalMinutes, forKey: "watchIntervalMinutes")
        }
    }

    private var session: WKExtendedRuntimeSession?
    private var timer: Timer?

    private let phrases: [String] = [
        "Come back to awareness",
        "Where is your attention?",
        "Breathe",
        "This moment",
        "Notice what is here",
        "Return to presence",
        "What are you feeling now?",
        "Be here fully",
        "Pause and notice",
        "Let go of the story",
        "Feel your body",
        "Just this breath",
        "Awareness is already here",
        "What is happening right now?",
        "Relax into this moment",
    ]

    override init() {
        self.intervalMinutes = UserDefaults.standard.object(forKey: "watchIntervalMinutes") as? Int ?? 5
        super.init()
        startTimer()
        startSession()
    }

    // MARK: - Session Management

    func startSession() {
        guard session == nil || session?.state == .invalid else { return }
        let newSession = WKExtendedRuntimeSession()
        newSession.delegate = self
        newSession.start()
        session = newSession
    }

    private func startTimer() {
        timer?.invalidate()
        lastReminderDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    deinit {
        timer?.invalidate()
        session?.invalidate()
    }

    // MARK: - Snooze

    var isSnoozed: Bool {
        if let until = snoozeUntil, until > Date() { return true }
        return false
    }

    var snoozeRemainingMinutes: Int? {
        guard let until = snoozeUntil, until > Date() else { return nil }
        return Int(ceil(until.timeIntervalSince(Date()) / 60.0))
    }

    func snooze() {
        if let until = snoozeUntil, until > Date() {
            snoozeUntil = until.addingTimeInterval(15 * 60)
        } else {
            snoozeUntil = Date().addingTimeInterval(15 * 60)
        }
    }

    func resume() {
        snoozeUntil = nil
        lastReminderDate = Date()
    }

    // MARK: - Tick

    private func tick() {
        guard isActive else { return }

        if isSnoozed {
            if let until = snoozeUntil, until <= Date() {
                snoozeUntil = nil
                lastReminderDate = Date()
            }
            return
        }

        let elapsed = Date().timeIntervalSince(lastReminderDate)
        if elapsed >= TimeInterval(intervalMinutes) * 60.0 {
            fireReminder()
            lastReminderDate = Date()
        }
    }

    private func fireReminder() {
        WKInterfaceDevice.current().play(hapticType)
        lastReminderPhrase = phrases.randomElement()
    }

    // MARK: - WKExtendedRuntimeSessionDelegate

    nonisolated func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: (any Error)?
    ) {
        Task { @MainActor in
            self.session = nil
            self.startSession()
        }
    }

    nonisolated func extendedRuntimeSessionDidStart(
        _ extendedRuntimeSession: WKExtendedRuntimeSession
    ) {}

    nonisolated func extendedRuntimeSessionWillExpire(
        _ extendedRuntimeSession: WKExtendedRuntimeSession
    ) {
        Task { @MainActor in
            self.session = nil
            self.startSession()
        }
    }
}
