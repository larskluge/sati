#if os(macOS)
import XCTest
import AppKit
@testable import Sati

@MainActor
final class ForcedBreakManagerTests: XCTestCase {

    private var manager: ForcedBreakManager!

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    // MARK: - Return-from-absence decision

    func testTimeAwayDuringBreakCountsAsBreakTime() {
        XCTAssertEqual(
            ForcedBreakManager.returnOutcome(
                phase: .onBreak, awaySeconds: 60,
                breakSecondsRemaining: 5 * 60, breakSeconds: 5 * 60),
            .continueBreak(secondsRemaining: 4 * 60),
            "A minute away should leave a minute less of break to sit through")
    }

    func testBreakEndsWhenAwayLongerThanTimeLeftOnIt() {
        // Locked 38s into a 5 min break, back 10 minutes later.
        XCTAssertEqual(
            ForcedBreakManager.returnOutcome(
                phase: .onBreak, awaySeconds: 10 * 60,
                breakSecondsRemaining: 4 * 60 + 22, breakSeconds: 5 * 60),
            .startWork)
    }

    func testBreakEndsWhenAwayExactlyAsLongAsTimeLeftOnIt() {
        XCTAssertEqual(
            ForcedBreakManager.returnOutcome(
                phase: .onBreak, awaySeconds: 262,
                breakSecondsRemaining: 262, breakSeconds: 5 * 60),
            .startWork)
    }

    func testReturningAfterBreakRanOutNeedsNoAcknowledgement() {
        XCTAssertEqual(
            ForcedBreakManager.returnOutcome(
                phase: .breakOver, awaySeconds: 30,
                breakSecondsRemaining: 0, breakSeconds: 5 * 60),
            .startWork)
    }

    func testLongAbsenceWhileWorkingCountsAsABreak() {
        XCTAssertEqual(
            ForcedBreakManager.returnOutcome(
                phase: .work, awaySeconds: 5 * 60,
                breakSecondsRemaining: 0, breakSeconds: 5 * 60),
            .startWork)
    }

    func testShortAbsenceWhileWorkingJustResumes() {
        XCTAssertEqual(
            ForcedBreakManager.returnOutcome(
                phase: .work, awaySeconds: 60,
                breakSecondsRemaining: 0, breakSeconds: 5 * 60),
            .resume)
    }

    func testLongAbsenceWithBreakDueCountsAsThatBreak() {
        XCTAssertEqual(
            ForcedBreakManager.returnOutcome(
                phase: .finishUp, awaySeconds: 6 * 60,
                breakSecondsRemaining: 0, breakSeconds: 5 * 60),
            .startWork)
    }

    func testShortAbsenceWithBreakDueStillOwesTheBreak() {
        XCTAssertEqual(
            ForcedBreakManager.returnOutcome(
                phase: .finishUp, awaySeconds: 60,
                breakSecondsRemaining: 0, breakSeconds: 5 * 60),
            .resume)
    }

    func testLongAbsenceWhileSnoozedCountsAsABreak() {
        XCTAssertEqual(
            ForcedBreakManager.returnOutcome(
                phase: .snoozed, awaySeconds: 6 * 60,
                breakSecondsRemaining: 0, breakSeconds: 5 * 60),
            .startWork)
    }

    func testDisabledBreaksIgnoreAbsences() {
        XCTAssertEqual(
            ForcedBreakManager.returnOutcome(
                phase: .disabled, awaySeconds: 60 * 60,
                breakSecondsRemaining: 0, breakSeconds: 5 * 60),
            .resume)
    }

    // MARK: - Notification wiring

    func testTimerPausesOnScreenLockNotification() {
        manager = ForcedBreakManager()
        XCTAssertEqual(manager.phase, .work)
        XCTAssertFalse(manager.isAway)

        // Post screen lock notification — what macOS sends when user locks screen
        // (fires immediately, before display physically sleeps)
        DistributedNotificationCenter.default().post(
            name: Notification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))

        XCTAssertTrue(manager.isAway,
            "Timer should pause immediately on screen lock, not wait for display sleep")
    }

    func testTimerResetsOnScreenUnlockAfterLongAbsence() {
        manager = ForcedBreakManager()
        XCTAssertEqual(manager.workSecondsRemaining, 40 * 60)

        // Simulate screen lock
        DistributedNotificationCenter.default().post(
            name: Notification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))

        // Backdate lock time to simulate 10 min absence (well above 5 min threshold)
        manager.awayStartedAt = Date().addingTimeInterval(-600)

        // Simulate screen unlock
        DistributedNotificationCenter.default().post(
            name: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))

        // Allow 2s tolerance for timer ticks during RunLoop spins
        XCTAssertGreaterThan(manager.workSecondsRemaining, 40 * 60 - 2,
            "Timer should reset to full duration after long absence from screen lock")
        XCTAssertEqual(manager.phase, .work)
        XCTAssertFalse(manager.isAway)
    }

    func testLockDuringBreakThenLongAbsenceStartsFreshWorkPeriod() {
        manager = ForcedBreakManager()
        // Phase is set directly rather than via startBreak(), which would put a
        // full-screen overlay up for the duration of the test run.
        manager.phase = .onBreak
        manager.breakSecondsRemaining = 4 * 60 + 22

        DistributedNotificationCenter.default().post(
            name: Notification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        XCTAssertTrue(manager.isAway)

        manager.awayStartedAt = Date().addingTimeInterval(-600)

        DistributedNotificationCenter.default().post(
            name: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))

        XCTAssertEqual(manager.phase, .work,
            "10 minutes away more than covers what was left of the break")
        XCTAssertGreaterThan(manager.workSecondsRemaining, 40 * 60 - 2,
            "The work period should be counted from the moment of return")
    }

    func testDisplayWakingToLoginWindowIsNotAReturn() {
        manager = ForcedBreakManager()
        manager.isScreenLocked = { true }

        DistributedNotificationCenter.default().post(
            name: Notification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        XCTAssertTrue(manager.isAway)

        manager.awayStartedAt = Date().addingTimeInterval(-600)
        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))

        XCTAssertTrue(manager.isAway,
            "Waking the display to a login window is not the user coming back")

        manager.isScreenLocked = { false }
        DistributedNotificationCenter.default().post(
            name: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))

        XCTAssertFalse(manager.isAway)
        XCTAssertEqual(manager.phase, .work)
    }
}
#endif
