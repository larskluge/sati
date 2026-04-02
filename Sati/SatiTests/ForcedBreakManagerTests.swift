#if os(macOS)
import XCTest
@testable import Sati

@MainActor
final class ForcedBreakManagerTests: XCTestCase {

    private var manager: ForcedBreakManager!

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    func testTimerPausesOnScreenLockNotification() {
        manager = ForcedBreakManager()
        XCTAssertEqual(manager.phase, .work)
        XCTAssertFalse(manager.paused)

        // Post screen lock notification — what macOS sends when user locks screen
        // (fires immediately, before display physically sleeps)
        DistributedNotificationCenter.default().post(
            name: Notification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))

        XCTAssertTrue(manager.paused,
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
        manager.screenLockedAt = Date().addingTimeInterval(-600)

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
        XCTAssertFalse(manager.paused)
    }
}
#endif
