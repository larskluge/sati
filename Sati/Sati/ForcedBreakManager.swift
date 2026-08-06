#if os(macOS)
import AppKit
import AVFoundation
import Combine
import CoreGraphics

enum ForcedBreakPhase: Equatable {
    case disabled
    case work
    case finishUp
    case snoozed
    case onBreak
    case breakOver
}

/// What coming back to the screen means for the phase that was running when
/// the user left.
enum ForcedBreakReturn: Equatable {
    /// The time away satisfied the break — start a fresh work period.
    case startWork
    /// Still on break, with this many seconds to go.
    case continueBreak(secondsRemaining: Int)
    /// Nothing break-worthy happened — pick up where we left off.
    case resume
}

final class ForcedBreakManager: ObservableObject {

    @Published var phase: ForcedBreakPhase = .work

    // NOT @Published: these tick every second. Publishing them would invalidate
    // the SwiftUI popover body every second even when hidden, causing continuous
    // layout passes on NSHostingView (~10% CPU). Views that display these values
    // should use TimelineView so they only re-read while actually visible.
    var workSecondsRemaining: Int = 0
    var breakSecondsRemaining: Int = 0
    var overtimeSeconds: Int = 0

    @Published var breakEnabled: Bool {
        didSet { UserDefaults.standard.set(breakEnabled, forKey: "breakEnabled") }
    }
    @Published var workDurationMinutes: Int {
        didSet {
            UserDefaults.standard.set(workDurationMinutes, forKey: "workDurationMinutes")
            if phase == .work { resetWorkTimer() }
        }
    }
    @Published var breakDurationMinutes: Int {
        didSet { UserDefaults.standard.set(breakDurationMinutes, forKey: "breakDurationMinutes") }
    }
    @Published var breakSoundEnabled: Bool {
        didSet { UserDefaults.standard.set(breakSoundEnabled, forKey: "breakSoundEnabled") }
    }

    private var timer: Timer?
    private var breakSoundPlayer: AVAudioPlayer?
    private var snoozeSecondsRemaining: Int = 0
    /// When the user left the screen, or nil while they are present. Every
    /// countdown is frozen for as long as this is set.
    var awayStartedAt: Date?
    /// Whether the login window is up. Injectable so tests can simulate it.
    var isScreenLocked: () -> Bool = ForcedBreakManager.screenIsLocked
    private var workspaceObservers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []

    private lazy var vignetteController = VignetteOverlayController()
    private lazy var breakController = BreakOverlayController()

    init() {
        self.breakEnabled = UserDefaults.standard.object(forKey: "breakEnabled") as? Bool ?? true
        self.workDurationMinutes = UserDefaults.standard.object(forKey: "workDurationMinutes") as? Int ?? 40
        self.breakDurationMinutes = UserDefaults.standard.object(forKey: "breakDurationMinutes") as? Int ?? 5
        self.breakSoundEnabled = UserDefaults.standard.object(forKey: "breakSoundEnabled") as? Bool ?? true

        if breakEnabled {
            phase = .work
            workSecondsRemaining = workDurationMinutes * 60
        } else {
            phase = .disabled
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }

        let wsnc = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(wsnc.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.beginAway()
        })
        workspaceObservers.append(wsnc.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            // The display also wakes to a login window the user has not typed
            // their password into yet. Only a wake into an unlocked session
            // means they are actually back; otherwise wait for the unlock.
            guard let self = self, !self.isScreenLocked() else { return }
            self.endAway()
        })

        let dnc = DistributedNotificationCenter.default()
        distributedObservers.append(dnc.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.beginAway()
        })
        distributedObservers.append(dnc.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            self?.endAway()
        })
    }

    deinit {
        timer?.invalidate()
        let wsnc = NSWorkspace.shared.notificationCenter
        for observer in workspaceObservers { wsnc.removeObserver(observer) }
        let dnc = DistributedNotificationCenter.default()
        for observer in distributedObservers { dnc.removeObserver(observer) }
    }

    // MARK: - Away From Screen

    /// True while the user is away — the screen is locked or the displays are
    /// asleep — and every countdown is frozen.
    var isAway: Bool { awayStartedAt != nil }

    /// True while the login window is up. Read from the window server rather
    /// than tracked from lock/unlock notifications, so a dropped notification
    /// cannot leave the timers stuck paused. Unknown → treat as unlocked.
    nonisolated static func screenIsLocked() -> Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return (session["CGSSessionScreenIsLocked"] as? NSNumber)?.boolValue ?? false
    }

    private func beginAway() {
        guard phase != .disabled, awayStartedAt == nil else { return }
        SatiLog.info("Break", "away from screen, paused")
        awayStartedAt = Date()
        if phase == .finishUp {
            vignetteController.hide()
        }
    }

    private func endAway() {
        guard let startedAt = awayStartedAt else { return }
        let awaySeconds = Int(Date().timeIntervalSince(startedAt))
        awayStartedAt = nil

        switch Self.returnOutcome(
            phase: phase,
            awaySeconds: awaySeconds,
            breakSecondsRemaining: breakSecondsRemaining,
            breakSeconds: breakDurationMinutes * 60
        ) {
        case .startWork:
            SatiLog.info("Break", "back at screen, counted as break", extra: [("d", Self.duration(awaySeconds))])
            vignetteController.hide()
            breakController.dismiss()
            resetWorkTimer()

        case .continueBreak(let secondsRemaining):
            SatiLog.info("Break", "back at screen, break continues", extra: [
                ("d", Self.duration(awaySeconds)),
                ("left", Self.duration(secondsRemaining)),
            ])
            breakSecondsRemaining = secondsRemaining
            breakController.updateTime(secondsRemaining)

        case .resume:
            SatiLog.info("Break", "back at screen, resuming", extra: [("d", Self.duration(awaySeconds))])
            if phase == .finishUp {
                vignetteController.fadeIn(duration: 0.5)
            }
        }
    }

    /// Time away from the screen is time not spent working, so it counts as
    /// break time: an absence can finish a running break, shorten it, or stand
    /// in for one that was due. Either way the work period is measured from the
    /// moment the user comes back.
    static func returnOutcome(
        phase: ForcedBreakPhase,
        awaySeconds: Int,
        breakSecondsRemaining: Int,
        breakSeconds: Int
    ) -> ForcedBreakReturn {
        switch phase {
        case .disabled:
            return .resume

        case .onBreak:
            let left = breakSecondsRemaining - awaySeconds
            return left > 0 ? .continueBreak(secondsRemaining: left) : .startWork

        case .breakOver:
            // The break already ran its course — no "Continue" click needed for
            // one the user has clearly already taken.
            return .startWork

        case .work, .finishUp, .snoozed:
            return awaySeconds >= breakSeconds ? .startWork : .resume
        }
    }

    // MARK: - Actions

    func startBreak() {
        SatiLog.info("Break", "starting break", extra: [("d", "\(breakDurationMinutes)m")])
        vignetteController.fadeOut(duration: 0.5)
        phase = .onBreak
        breakSecondsRemaining = breakDurationMinutes * 60
        breakController.show(seconds: breakSecondsRemaining, breakSoundEnabled: breakSoundEnabled) { [weak self] in
            self?.dismissBreak()
        }
    }

    func snooze() {
        SatiLog.info("Break", "snoozed", extra: [("d", "2m")])
        vignetteController.fadeOut(duration: 0.5)
        phase = .snoozed
        snoozeSecondsRemaining = 2 * 60
    }

    func dismissBreak() {
        let total = breakDurationMinutes * 60
        var attrs: [(String, String)] = [("d", "\(breakDurationMinutes)m")]
        if phase == .onBreak {
            attrs.append(("actual", Self.duration(total - breakSecondsRemaining)))
            SatiLog.info("Break", "break ended early", extra: attrs)
        } else {
            attrs.append(("actual", Self.duration(total + overtimeSeconds)))
            SatiLog.info("Break", "break over", extra: attrs)
        }
        breakController.dismiss()
        resetWorkTimer()
    }

    func setEnabled(_ enabled: Bool) {
        breakEnabled = enabled
        if enabled {
            resetWorkTimer()
        } else {
            vignetteController.hide()
            breakController.dismiss()
            phase = .disabled
        }
    }

    // MARK: - Timer

    private func tick() {
        if isAway { return }

        switch phase {
        case .disabled:
            return

        case .work:
            workSecondsRemaining -= 1
            if workSecondsRemaining <= 0 {
                SatiLog.info("Break", "break due")
                phase = .finishUp
                vignetteController.fadeIn(duration: 5.0)
            }

        case .finishUp:
            break

        case .snoozed:
            snoozeSecondsRemaining -= 1
            if snoozeSecondsRemaining <= 0 {
                SatiLog.info("Break", "break due")
                phase = .finishUp
                vignetteController.fadeIn(duration: 5.0)
            }

        case .onBreak:
            breakSecondsRemaining -= 1
            breakController.updateTime(breakSecondsRemaining)
            if breakSecondsRemaining <= 0 {
                phase = .breakOver
                overtimeSeconds = 0
                playBreakSound()
                breakController.showBreakOver(breakDurationMinutes: breakDurationMinutes)
            }

        case .breakOver:
            overtimeSeconds += 1
            breakController.updateOvertime(overtimeSeconds)
        }
    }

    private func playBreakSound() {
        guard breakSoundEnabled else { return }
        guard let url = Bundle.main.url(forResource: "deep-bowl", withExtension: "caf") else {
            SatiLog.error("Break", "break sound not found")
            return
        }
        breakSoundPlayer = try? AVAudioPlayer(contentsOf: url)
        breakSoundPlayer?.play()
    }

    private func resetWorkTimer() {
        phase = .work
        workSecondsRemaining = workDurationMinutes * 60
    }

    // MARK: - Computed

    var workMinutesRemaining: Int {
        max(0, (workSecondsRemaining + 59) / 60)
    }

    private static func duration(_ seconds: Int) -> String {
        "\(seconds / 60)m\(seconds % 60)s"
    }
}
#endif
