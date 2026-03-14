import XCTest
@testable import SatiWatch

/// Tests TopicRotation in the watchOS target to verify the shared copy behaves identically.
final class WatchTopicRotationTests: XCTestCase {

    func testActiveIndex_rotates() {
        XCTAssertEqual(TopicRotation.activeIndex(slot: 0, offset: 0, count: 3), 0)
        XCTAssertEqual(TopicRotation.activeIndex(slot: 1, offset: 0, count: 3), 1)
        XCTAssertEqual(TopicRotation.activeIndex(slot: 2, offset: 0, count: 3), 2)
        XCTAssertEqual(TopicRotation.activeIndex(slot: 3, offset: 0, count: 3), 0)
    }

    func testActiveIndex_empty() {
        XCTAssertNil(TopicRotation.activeIndex(slot: 0, offset: 0, count: 0))
    }

    func testOffset_roundTrip() {
        for slot in 0...5 {
            for desired in 0..<4 {
                let off = TopicRotation.offset(forDesiredIndex: desired, slot: slot, count: 4)
                XCTAssertEqual(TopicRotation.activeIndex(slot: slot, offset: off, count: 4), desired)
            }
        }
    }
}
