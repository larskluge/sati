import Foundation
import UserNotifications
import Combine
import AppKit

final class ReminderManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    static let categoryID = "MINDFULNESS_REMINDER"
    static let snooze15Action = "SNOOZE_15"
    static let snooze30Action = "SNOOZE_30"
    static let moreAction = "MORE"

    @Published var isActive: Bool = true
    @Published var snoozeUntil: Date?
    @Published var snoozedForVLC: Bool = false
    @Published var showExtendedSnooze: Bool = false

    @Published var intervalMinutes: Int {
        didSet {
            UserDefaults.standard.set(intervalMinutes, forKey: "intervalMinutes")
        }
    }

    var onOpenPopover: (() -> Void)?

    private var timer: Timer?
    private var lastNotificationDate: Date = Date()
    private var cancellables = Set<AnyCancellable>()

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
        self.intervalMinutes = UserDefaults.standard.object(forKey: "intervalMinutes") as? Int ?? 5
        super.init()

        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // Register actions
        let snooze15 = UNNotificationAction(identifier: Self.snooze15Action, title: "Snooze 15m")
        let snooze30 = UNNotificationAction(identifier: Self.snooze30Action, title: "Snooze 30m")
        let more = UNNotificationAction(identifier: Self.moreAction, title: "More...", options: .foreground)

        let category = UNNotificationCategory(
            identifier: Self.categoryID,
            actions: [snooze15, snooze30, more],
            intentIdentifiers: []
        )
        center.setNotificationCategories([category])

        // Request permission
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }

        // Start timer
        lastNotificationDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    deinit {
        timer?.invalidate()
    }

    func connectVLCMonitor(_ vlcMonitor: VLCMonitor) {
        vlcMonitor.$isVLCRunning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] running in
                guard let self = self else { return }
                if !running && self.snoozedForVLC {
                    self.resume()
                }
            }
            .store(in: &cancellables)
    }

    var isSnoozed: Bool {
        if snoozedForVLC { return true }
        if let until = snoozeUntil, until > Date() { return true }
        return false
    }

    var statusText: String {
        if snoozedForVLC {
            return "Snoozed while VLC plays"
        }
        if let until = snoozeUntil, until > Date() {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Snoozed until \(formatter.string(from: until))"
        }
        return "Active"
    }

    func snooze(minutes: Int) {
        snoozeUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        snoozedForVLC = false
    }

    func snoozeForVLC() {
        snoozedForVLC = true
        snoozeUntil = nil
    }

    func resume() {
        snoozeUntil = nil
        snoozedForVLC = false
        lastNotificationDate = Date()
    }

    private func tick() {
        guard isActive else { return }
        if isSnoozed {
            // Check if timed snooze expired
            if let until = snoozeUntil, until <= Date() {
                snoozeUntil = nil
                lastNotificationDate = Date()
            }
            return
        }

        let elapsed = Date().timeIntervalSince(lastNotificationDate)
        if elapsed >= TimeInterval(intervalMinutes) * 60.0 {
            sendNotification()
            lastNotificationDate = Date()
        }
    }

    private func sendNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Sati"
        content.body = phrases.randomElement() ?? "Breathe"
        content.categoryIdentifier = Self.categoryID
        content.sound = UNNotificationSound(named: UNNotificationSoundName("bowl.aif"))

        let id = UUID().uuidString
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: nil
        )
        let center = UNUserNotificationCenter.current()
        center.add(request)

        // Remove from Notification Center and lock screen after the banner dismisses
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            center.removeDeliveredNotifications(withIdentifiers: [id])
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {
        case Self.snooze15Action:
            snooze(minutes: 15)
        case Self.snooze30Action:
            snooze(minutes: 30)
        case Self.moreAction:
            showExtendedSnooze = true
            onOpenPopover?()
        default:
            break
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
