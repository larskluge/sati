#if os(macOS)
import XCTest
@testable import Sati

@MainActor
final class ReminderManagerTests: XCTestCase {

    private var reminderManager: ReminderManager!
    private var breakManager: ForcedBreakManager!

    override func setUp() {
        super.setUp()
        reminderManager = ReminderManager()
        reminderManager.intervalMinutes = 1 // 60s interval for test math
        breakManager = ForcedBreakManager()
        reminderManager.forcedBreakManager = breakManager
        // Put lastNotificationDate far in the past so the interval is always
        // considered elapsed — every tick() is a "would fire" moment.
        reminderManager.lastNotificationDate = Date(timeIntervalSinceNow: -3600)
    }

    override func tearDown() {
        reminderManager = nil
        breakManager = nil
        super.tearDown()
    }

    private func assertReminderDidNotFire(phase: ForcedBreakPhase, line: UInt = #line) {
        let before = reminderManager.lastNotificationDate
        breakManager.phase = phase
        reminderManager.tick()
        XCTAssertEqual(reminderManager.lastNotificationDate, before,
                       "Reminder should be suppressed in \(phase)", line: line)
    }

    private func assertReminderDidFire(phase: ForcedBreakPhase, line: UInt = #line) {
        let before = reminderManager.lastNotificationDate
        breakManager.phase = phase
        reminderManager.tick()
        XCTAssertGreaterThan(reminderManager.lastNotificationDate, before,
                             "Reminder should fire in \(phase)", line: line)
    }

    func testSuppressedInFinishUp() {
        assertReminderDidNotFire(phase: .finishUp)
    }

    func testSuppressedInSnoozed() {
        assertReminderDidNotFire(phase: .snoozed)
    }

    func testSuppressedInOnBreak() {
        assertReminderDidNotFire(phase: .onBreak)
    }

    func testSuppressedInBreakOver() {
        assertReminderDidNotFire(phase: .breakOver)
    }

    func testFiresInWork() {
        assertReminderDidFire(phase: .work)
    }

    func testFiresInDisabled() {
        assertReminderDidFire(phase: .disabled)
    }

    func testResetsLastNotificationDateOnExitingSuppressedPhase() {
        // Enter a suppressed phase; reminder should not fire.
        breakManager.phase = .onBreak
        reminderManager.tick()

        // Exit back to work. The first tick after exit should NOT fire
        // (because the break counts as the mindfulness moment), and should
        // reset lastNotificationDate to ~now so a fresh interval must elapse.
        let beforeExit = Date()
        breakManager.phase = .work
        reminderManager.tick()

        XCTAssertGreaterThanOrEqual(reminderManager.lastNotificationDate, beforeExit,
                                    "lastNotificationDate should be reset to now on exit")
        XCTAssertLessThan(reminderManager.lastNotificationDate.timeIntervalSinceNow, 1.0,
                          "lastNotificationDate should be ~now after reset")

        // A follow-up tick immediately after should not fire either — full
        // interval has not elapsed.
        let afterReset = reminderManager.lastNotificationDate
        reminderManager.tick()
        XCTAssertEqual(reminderManager.lastNotificationDate, afterReset,
                       "Reminder should not fire again until a fresh interval elapses")
    }
}
#endif
