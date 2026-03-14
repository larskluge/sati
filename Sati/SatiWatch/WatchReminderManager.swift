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
            lastReminderDate = Date()
            scheduleNextTick()
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
        startSession()
    }

    // MARK: - Session Management

    func startSession() {
        guard session == nil || session?.state == .invalid else { return }
        let newSession = WKExtendedRuntimeSession()
        newSession.delegate = self
        newSession.start()
        session = newSession
        startTimer()
    }

    private func startTimer() {
        timer?.invalidate()
        lastReminderDate = Date()
        scheduleNextTick()
    }

    private func scheduleNextTick() {
        timer?.invalidate()
        guard isActive else { return }

        let now = Date()
        let nextFireDate: Date

        if let until = snoozeUntil, until > now {
            // Snoozed — wake when snooze ends
            nextFireDate = until
        } else {
            // Active — wake when next reminder is due
            let elapsed = now.timeIntervalSince(lastReminderDate)
            let remaining = TimeInterval(intervalMinutes) * 60.0 - elapsed
            nextFireDate = now.addingTimeInterval(max(remaining, 0.1))
        }

        timer = Timer.scheduledTimer(withTimeInterval: nextFireDate.timeIntervalSince(now), repeats: false) { [weak self] _ in
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
        scheduleNextTick()
    }

    func resume() {
        snoozeUntil = nil
        lastReminderDate = Date()
        scheduleNextTick()
    }

    // MARK: - Tick

    private func tick() {
        guard isActive else { return }

        if let until = snoozeUntil, until <= Date() {
            snoozeUntil = nil
            lastReminderDate = Date()
        } else if !isSnoozed {
            let elapsed = Date().timeIntervalSince(lastReminderDate)
            if elapsed >= TimeInterval(intervalMinutes) * 60.0 {
                fireReminder()
                lastReminderDate = Date()
            }
        }

        scheduleNextTick()
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
