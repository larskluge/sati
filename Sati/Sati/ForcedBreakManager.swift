#if os(macOS)
import Foundation
import Combine

enum ForcedBreakPhase {
    case disabled
    case work
    case finishUp
    case snoozed
    case onBreak
}

final class ForcedBreakManager: ObservableObject {

    @Published var phase: ForcedBreakPhase = .work
    @Published var workSecondsRemaining: Int = 0
    @Published var breakSecondsRemaining: Int = 0

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

    private var timer: Timer?
    private var snoozeSecondsRemaining: Int = 0

    private lazy var vignetteController = VignetteOverlayController()
    private lazy var breakController = BreakOverlayController()

    init() {
        self.breakEnabled = UserDefaults.standard.object(forKey: "breakEnabled") as? Bool ?? true
        self.workDurationMinutes = UserDefaults.standard.object(forKey: "workDurationMinutes") as? Int ?? 40
        self.breakDurationMinutes = UserDefaults.standard.object(forKey: "breakDurationMinutes") as? Int ?? 5

        if breakEnabled {
            phase = .work
            workSecondsRemaining = workDurationMinutes * 60
        } else {
            phase = .disabled
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Actions

    func startBreak() {
        SatiLog.info("Break", "starting break (\(breakDurationMinutes) min)")
        vignetteController.fadeOut(duration: 0.5)
        phase = .onBreak
        breakSecondsRemaining = breakDurationMinutes * 60
        breakController.show(seconds: breakSecondsRemaining) { [weak self] in
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
                SatiLog.info("Break", "break complete")
                dismissBreak()
            }
        }
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
