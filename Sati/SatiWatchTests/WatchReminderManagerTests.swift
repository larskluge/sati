import XCTest
import WatchKit
@testable import SatiWatch

@MainActor
final class WatchReminderManagerTests: XCTestCase {

    private var manager: WatchReminderManager!

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    func testAppBecomeActive_resetsFailCount() {
        manager = WatchReminderManager()
        manager.sessionFailCount = 3

        NotificationCenter.default.post(name: WKApplication.didBecomeActiveNotification, object: nil)

        XCTAssertEqual(manager.sessionFailCount, 0)
    }

    func testAppBecomeActive_doesNothingWhenUnderLimit() {
        manager = WatchReminderManager()
        manager.sessionFailCount = 2

        NotificationCenter.default.post(name: WKApplication.didBecomeActiveNotification, object: nil)

        XCTAssertEqual(manager.sessionFailCount, 2)
    }
}
