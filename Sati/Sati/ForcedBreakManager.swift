#if os(macOS)
import AppKit
import AVFoundation
import Combine

enum ForcedBreakPhase: Equatable {
    case disabled
    case work
    case finishUp
    case snoozed
    case onBreak
    case breakOver
}

final class ForcedBreakManager: ObservableObject {

    @Published var phase: ForcedBreakPhase = .work
    @Published var workSecondsRemaining: Int = 0
    @Published var breakSecondsRemaining: Int = 0
    @Published var overtimeSeconds: Int = 0

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
    var screenLockedAt: Date?
    private var phaseBeforeLock: ForcedBreakPhase?
    var paused: Bool = false
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
            self?.screenDidSleep()
        })
        workspaceObservers.append(wsnc.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.screenDidWake()
        })

        let dnc = DistributedNotificationCenter.default()
        distributedObservers.append(dnc.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.screenDidSleep()
        })
        distributedObservers.append(dnc.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            self?.screenDidWake()
        })
    }

    deinit {
        timer?.invalidate()
        let wsnc = NSWorkspace.shared.notificationCenter
        for observer in workspaceObservers { wsnc.removeObserver(observer) }
        let dnc = DistributedNotificationCenter.default()
        for observer in distributedObservers { dnc.removeObserver(observer) }
    }

    // MARK: - Screen Lock

    private func screenDidSleep() {
        guard phase != .disabled, !paused else { return }
        SatiLog.info("Break", "screen locked, pausing timer (phase: \(phase))")
        screenLockedAt = Date()
        phaseBeforeLock = phase
        paused = true
        if phase == .finishUp {
            vignetteController.hide()
        }
    }

    private func screenDidWake() {
        guard paused, let lockedAt = screenLockedAt else { return }
        let lockedSeconds = Int(Date().timeIntervalSince(lockedAt))
        let breakThreshold = breakDurationMinutes * 60
        paused = false
        screenLockedAt = nil

        if lockedSeconds >= breakThreshold {
            SatiLog.info("Break", "screen unlocked after \(lockedSeconds)s (>= break duration), resetting work timer")
            vignetteController.hide()
            breakController.dismiss()
            resetWorkTimer()
        } else {
            SatiLog.info("Break", "screen unlocked after \(lockedSeconds)s (< break duration), resuming")
            if let prev = phaseBeforeLock, prev == .finishUp {
                phase = .finishUp
                vignetteController.fadeIn(duration: 0.5)
            }
        }
        phaseBeforeLock = nil
    }

    // MARK: - Actions

    func startBreak() {
        SatiLog.info("Break", "starting break (\(breakDurationMinutes) min)")
        vignetteController.fadeOut(duration: 0.5)
        phase = .onBreak
        breakSecondsRemaining = breakDurationMinutes * 60
        breakController.show(seconds: breakSecondsRemaining, breakSoundEnabled: breakSoundEnabled) { [weak self] in
            self?.dismissBreak()
        }
    }

    func snooze() {
        SatiLog.info("Break", "snoozed for 2 min")
        vignetteController.fadeOut(duration: 0.5)
        phase = .snoozed
        snoozeSecondsRemaining = 2 * 60
    }

    func dismissBreak() {
        SatiLog.info("Break", "break dismissed")
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
        if paused { return }

        switch phase {
        case .disabled:
            return

        case .work:
            workSecondsRemaining -= 1
            if workSecondsRemaining <= 0 {
                SatiLog.info("Break", "work timer elapsed, showing vignette")
                phase = .finishUp
                vignetteController.fadeIn(duration: 5.0)
            }

        case .finishUp:
            break

        case .snoozed:
            snoozeSecondsRemaining -= 1
            if snoozeSecondsRemaining <= 0 {
                SatiLog.info("Break", "snooze elapsed, showing vignette")
                phase = .finishUp
                vignetteController.fadeIn(duration: 5.0)
            }

        case .onBreak:
            breakSecondsRemaining -= 1
            breakController.updateTime(breakSecondsRemaining)
            if breakSecondsRemaining <= 0 {
                SatiLog.info("Break", "break complete, waiting for user to continue")
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
            SatiLog.info("Break", "deep-bowl.caf not found")
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
}
#endif
