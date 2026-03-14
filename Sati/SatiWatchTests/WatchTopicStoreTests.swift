import XCTest
@testable import SatiWatch

@MainActor
final class WatchTopicStoreTests: XCTestCase {

    private var store: WatchTopicStore!

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    // MARK: - Init

    func testInit_emptyByDefault() {
        // Clear any persisted state from previous runs
        UserDefaults.standard.removeObject(forKey: "watchTopics")
        UserDefaults.standard.removeObject(forKey: "watchTopicOffset")
        store = WatchTopicStore()
        XCTAssertEqual(store.topics, [])
        XCTAssertNil(store.activeTopic)
    }

    // MARK: - Update

    func testUpdate_setsTopicsAndOffset() {
        store = WatchTopicStore()
        store.update(topics: ["x", "y"], offset: 3)
        XCTAssertEqual(store.topics, ["x", "y"])
        XCTAssertEqual(store.offset, 3)
    }

    func testActiveTopic_withTopics() {
        store = WatchTopicStore()
        store.update(topics: ["a", "b", "c"], offset: 0)
        XCTAssertNotNil(store.activeTopic)
        XCTAssertTrue(["a", "b", "c"].contains(store.activeTopic!))
    }

    func testActiveTopic_emptyTopics_isNil() {
        store = WatchTopicStore()
        store.update(topics: [], offset: 0)
        XCTAssertNil(store.activeTopic)
    }
}
