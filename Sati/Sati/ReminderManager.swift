import Foundation
import UserNotifications
import Combine
import AVFoundation

final class ReminderManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    static let categoryID = "MINDFULNESS_REMINDER"
    static let snooze15Action = "SNOOZE_15"
    static let snooze30Action = "SNOOZE_30"
    static let moreAction = "MORE"

    @Published var isActive: Bool {
        didSet {
            UserDefaults.standard.set(isActive, forKey: "isActive")
            if isActive {
                requestNotificationPermission()
            }
        }
    }
    @Published var snoozeUntil: Date?
    @Published var snoozedForVLC: Bool = false
    @Published var showExtendedSnooze: Bool = false

    @Published var intervalMinutes: Int {
        didSet {
            UserDefaults.standard.set(intervalMinutes, forKey: "intervalMinutes")
        }
    }

    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
        }
    }

    @Published var soundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled")
        }
    }

    @Published var dropAnimationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(dropAnimationEnabled, forKey: "dropAnimationEnabled")
        }
    }

    var topicManager: TopicManager?
    var onOpenPopover: (() -> Void)?
    #if os(macOS)
    var dropAnimationController: DropAnimationController?
    #endif

    private var timer: Timer?
    private var lastNotificationDate: Date = Date()
    private var cancellables = Set<AnyCancellable>()
    private var notificationSoundPlayer: AVAudioPlayer?

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
        #if os(iOS)
        let activeDefault = false
        #else
        let activeDefault = true
        #endif
        if UserDefaults.standard.object(forKey: "isActive") != nil {
            self.isActive = UserDefaults.standard.bool(forKey: "isActive")
        } else {
            self.isActive = activeDefault
        }
        self.intervalMinutes = UserDefaults.standard.object(forKey: "intervalMinutes") as? Int ?? 5
        self.notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        self.soundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
        self.dropAnimationEnabled = UserDefaults.standard.object(forKey: "dropAnimationEnabled") as? Bool ?? false
        super.init()

        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let snooze15 = UNNotificationAction(identifier: Self.snooze15Action, title: "Snooze 15m")
        let snooze30 = UNNotificationAction(identifier: Self.snooze30Action, title: "Snooze 30m")
        let more = UNNotificationAction(identifier: Self.moreAction, title: "More...", options: .foreground)

        let category = UNNotificationCategory(
            identifier: Self.categoryID,
            actions: [snooze15, snooze30, more],
            intentIdentifiers: []
        )
        center.setNotificationCategories([category])

        #if os(macOS)
        requestNotificationPermission()
        #endif

        lastNotificationDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    deinit {
        timer?.invalidate()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    #if os(macOS)
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
    #endif

    var isSnoozed: Bool {
        if snoozedForVLC { return true }
        if let until = snoozeUntil, until > Date() { return true }
        return false
    }

    var statusText: String {
        if snoozedForVLC {
            return "Paused while VLC plays"
        }
        if let until = snoozeUntil, until > Date() {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Paused until \(formatter.string(from: until))"
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
        SatiLog.info("Reminder", "sending notification")
        let content = UNMutableNotificationContent()
        let phrase = phrases.randomElement() ?? "Breathe"
        if let topic = topicManager?.activeTopic {
            content.title = "「\(topic)」"
            content.body = phrase
        } else {
            content.title = ""
            content.body = phrase
        }
        content.categoryIdentifier = Self.categoryID
        content.sound = nil
        if soundEnabled {
            if let url = Bundle.main.url(forResource: "tibetan-bowl", withExtension: "caf") {
                notificationSoundPlayer = try? AVAudioPlayer(contentsOf: url)
                notificationSoundPlayer?.play()
            }
        }
        #if os(macOS)
        if dropAnimationEnabled {
            dropAnimationController?.play()
        }
        #endif

        if notificationsEnabled {
            let id = UUID().uuidString
            let request = UNNotificationRequest(
                identifier: id,
                content: content,
                trigger: nil
            )
            let center = UNUserNotificationCenter.current()
            center.add(request)

            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                center.removeDeliveredNotifications(withIdentifiers: [id])
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        MainActor.assumeIsolated {
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
        }
        completionHandler()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
