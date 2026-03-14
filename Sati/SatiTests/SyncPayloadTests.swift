import XCTest
@testable import Sati

final class SyncPayloadTests: XCTestCase {

    private func payload(
        topics: [String] = ["a", "b"],
        offset: Int = 1,
        interval: Int = 15,
        updatedAt: Date = Date()
    ) -> SyncPayload {
        SyncPayload(topics: topics, topicOffset: offset, intervalMinutes: interval, updatedAt: updatedAt)
    }

    // MARK: - Serialization

    func testToDictionary_containsAllKeys() {
        let p = payload()
        let dict = p.toDictionary()
        XCTAssertNotNil(dict["topics"] as? [String])
        XCTAssertNotNil(dict["topicOffset"] as? Int)
        XCTAssertNotNil(dict["intervalMinutes"] as? Int)
        XCTAssertNotNil(dict["updatedAt"] as? Double)
    }

    func testToDictionary_values() {
        let date = Date(timeIntervalSince1970: 1000)
        let p = payload(topics: ["x", "y"], offset: 3, interval: 30, updatedAt: date)
        let dict = p.toDictionary()
        XCTAssertEqual(dict["topics"] as? [String], ["x", "y"])
        XCTAssertEqual(dict["topicOffset"] as? Int, 3)
        XCTAssertEqual(dict["intervalMinutes"] as? Int, 30)
        XCTAssertEqual(dict["updatedAt"] as? Double, 1000)
    }

    func testFromDictionary_roundTrip() {
        let original = payload(topics: ["one", "two"], offset: 5, interval: 20, updatedAt: Date(timeIntervalSince1970: 5000))
        let dict = original.toDictionary()
        let decoded = SyncPayload.fromDictionary(dict)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.topics, original.topics)
        XCTAssertEqual(decoded?.topicOffset, original.topicOffset)
        XCTAssertEqual(decoded?.intervalMinutes, original.intervalMinutes)
        XCTAssertEqual(decoded?.updatedAt.timeIntervalSince1970, original.updatedAt.timeIntervalSince1970)
    }

    func testFromDictionary_missingKey_returnsNil() {
        XCTAssertNil(SyncPayload.fromDictionary([:]))
        XCTAssertNil(SyncPayload.fromDictionary(["topics": ["a"]]))
        XCTAssertNil(SyncPayload.fromDictionary(["topics": ["a"], "topicOffset": 0]))
        XCTAssertNil(SyncPayload.fromDictionary(["topics": ["a"], "topicOffset": 0, "intervalMinutes": 15]))
    }

    func testFromDictionary_wrongType_returnsNil() {
        let dict: [String: Any] = [
            "topics": "not_array",
            "topicOffset": 0,
            "intervalMinutes": 15,
            "updatedAt": 1000.0,
        ]
        XCTAssertNil(SyncPayload.fromDictionary(dict))
    }

    // MARK: - contentHash

    func testContentHash_sameContent_sameHash() {
        let a = payload(topics: ["a"], offset: 1, interval: 10)
        let b = payload(topics: ["a"], offset: 1, interval: 10)
        XCTAssertEqual(a.contentHash(), b.contentHash())
    }

    func testContentHash_differentTopics_differentHash() {
        let a = payload(topics: ["a"])
        let b = payload(topics: ["b"])
        XCTAssertNotEqual(a.contentHash(), b.contentHash())
    }

    func testContentHash_differentOffset_differentHash() {
        let a = payload(offset: 1)
        let b = payload(offset: 2)
        XCTAssertNotEqual(a.contentHash(), b.contentHash())
    }

    func testContentHash_differentInterval_differentHash() {
        let a = payload(interval: 10)
        let b = payload(interval: 20)
        XCTAssertNotEqual(a.contentHash(), b.contentHash())
    }

    func testContentHash_ignoresTimestamp() {
        let a = payload(updatedAt: Date(timeIntervalSince1970: 100))
        let b = payload(updatedAt: Date(timeIntervalSince1970: 999))
        XCTAssertEqual(a.contentHash(), b.contentHash(), "contentHash should not include updatedAt")
    }

    // MARK: - shouldReplace

    func testShouldReplace_newerReplacesOlder() {
        let older = payload(updatedAt: Date(timeIntervalSince1970: 100))
        let newer = payload(updatedAt: Date(timeIntervalSince1970: 200))
        XCTAssertTrue(newer.shouldReplace(older))
        XCTAssertFalse(older.shouldReplace(newer))
    }

    func testShouldReplace_sameTimestamp_doesNotReplace() {
        let date = Date(timeIntervalSince1970: 100)
        let a = payload(updatedAt: date)
        let b = payload(updatedAt: date)
        XCTAssertFalse(a.shouldReplace(b))
    }
}
