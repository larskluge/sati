import XCTest
@testable import SatiWatch

/// Tests WatchContextCoder in the watchOS target.
final class WatchContextCoderWatchTests: XCTestCase {

    func testRoundTrip() {
        let original = WatchContext(topics: ["a", "b"], topicOffset: 1, intervalMinutes: 15)
        let dict = WatchContextCoder.encode(original)!
        let decoded = WatchContextCoder.decode(dict)
        XCTAssertEqual(decoded, original)
    }

    func testDecode_fromStringArray() {
        let dict: [String: Any] = [
            "topics": ["x", "y"],
            "topicOffset": 0,
            "intervalMinutes": 10,
        ]
        let decoded = WatchContextCoder.decode(dict)
        XCTAssertEqual(decoded?.topics, ["x", "y"])
    }

    func testDecode_invalid_returnsNil() {
        XCTAssertNil(WatchContextCoder.decode([:]))
    }
}
