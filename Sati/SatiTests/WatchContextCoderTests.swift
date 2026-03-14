import XCTest
@testable import Sati

final class WatchContextCoderTests: XCTestCase {

    // MARK: - Encode

    func testEncode_producesExpectedKeys() {
        let ctx = WatchContext(topics: ["a"], topicOffset: 1, intervalMinutes: 15)
        let dict = WatchContextCoder.encode(ctx)
        XCTAssertNotNil(dict)
        XCTAssertNotNil(dict?["topics"])
        XCTAssertEqual(dict?["topicOffset"] as? Int, 1)
        XCTAssertEqual(dict?["intervalMinutes"] as? Int, 15)
    }

    func testEncode_topicsAsData() {
        let ctx = WatchContext(topics: ["x", "y"], topicOffset: 0, intervalMinutes: 10)
        let dict = WatchContextCoder.encode(ctx)!
        XCTAssertTrue(dict["topics"] is Data, "Topics should be encoded as JSON Data")
    }

    // MARK: - Decode from Data (iOS sender path)

    func testDecode_fromEncodedData_roundTrip() {
        let original = WatchContext(topics: ["alpha", "beta"], topicOffset: 3, intervalMinutes: 20)
        let dict = WatchContextCoder.encode(original)!
        let decoded = WatchContextCoder.decode(dict)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Decode from [String] array (alternative path)

    func testDecode_fromStringArray() {
        let dict: [String: Any] = [
            "topics": ["a", "b", "c"],
            "topicOffset": 2,
            "intervalMinutes": 30,
        ]
        let decoded = WatchContextCoder.decode(dict)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.topics, ["a", "b", "c"])
        XCTAssertEqual(decoded?.topicOffset, 2)
        XCTAssertEqual(decoded?.intervalMinutes, 30)
    }

    // MARK: - Decode failures

    func testDecode_emptyDict_returnsNil() {
        XCTAssertNil(WatchContextCoder.decode([:]))
    }

    func testDecode_missingTopics_returnsNil() {
        let dict: [String: Any] = ["topicOffset": 0, "intervalMinutes": 10]
        XCTAssertNil(WatchContextCoder.decode(dict))
    }

    func testDecode_missingOffset_returnsNil() {
        let dict: [String: Any] = [
            "topics": try! JSONEncoder().encode(["a"]),
            "intervalMinutes": 10,
        ]
        XCTAssertNil(WatchContextCoder.decode(dict))
    }

    func testDecode_missingInterval_returnsNil() {
        let dict: [String: Any] = [
            "topics": try! JSONEncoder().encode(["a"]),
            "topicOffset": 0,
        ]
        XCTAssertNil(WatchContextCoder.decode(dict))
    }

    func testDecode_invalidTopicsType_returnsNil() {
        let dict: [String: Any] = [
            "topics": 42,
            "topicOffset": 0,
            "intervalMinutes": 10,
        ]
        XCTAssertNil(WatchContextCoder.decode(dict))
    }

    func testDecode_corruptedData_returnsNil() {
        let dict: [String: Any] = [
            "topics": Data([0xFF, 0xFE]),
            "topicOffset": 0,
            "intervalMinutes": 10,
        ]
        XCTAssertNil(WatchContextCoder.decode(dict))
    }

    // MARK: - Empty topics

    func testRoundTrip_emptyTopics() {
        let original = WatchContext(topics: [], topicOffset: 0, intervalMinutes: 5)
        let dict = WatchContextCoder.encode(original)!
        let decoded = WatchContextCoder.decode(dict)
        XCTAssertEqual(decoded, original)
    }
}
