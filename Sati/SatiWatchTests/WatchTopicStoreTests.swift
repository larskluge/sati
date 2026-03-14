import XCTest
@testable import SatiWatch

final class WatchTopicStoreTests: XCTestCase {

    // MARK: - Init

    func testInit_emptyByDefault() {
        let store = WatchTopicStore()
        XCTAssertEqual(store.topics, [])
        XCTAssertNil(store.activeTopic)
    }

    // MARK: - Update

    func testUpdate_setsTopicsAndOffset() {
        let store = WatchTopicStore()
        store.update(topics: ["x", "y"], offset: 3)
        XCTAssertEqual(store.topics, ["x", "y"])
        XCTAssertEqual(store.offset, 3)
    }

    func testActiveTopic_withTopics() {
        let store = WatchTopicStore()
        store.update(topics: ["a", "b", "c"], offset: 0)
        XCTAssertNotNil(store.activeTopic)
        XCTAssertTrue(["a", "b", "c"].contains(store.activeTopic!))
    }

    func testActiveTopic_emptyTopics_isNil() {
        let store = WatchTopicStore()
        store.update(topics: [], offset: 0)
        XCTAssertNil(store.activeTopic)
    }
}
