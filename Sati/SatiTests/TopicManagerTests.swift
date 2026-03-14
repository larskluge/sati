import XCTest
@testable import Sati

@MainActor
final class TopicManagerTests: XCTestCase {

    private var tm: TopicManager!

    override func tearDown() {
        tm = nil
        super.tearDown()
    }

    private func freshDefaults() -> UserDefaults {
        let name = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func makeManager(topics: [String] = [], offset: Int = 0) -> TopicManager {
        let defaults = freshDefaults()
        if !topics.isEmpty {
            defaults.set(try! JSONEncoder().encode(topics), forKey: "topics")
        }
        defaults.set(offset, forKey: "topicOffset")
        let m = TopicManager(defaults: defaults)
        tm = m
        return m
    }

    // MARK: - Init

    func testInit_empty() {
        let m = makeManager()
        XCTAssertEqual(m.topics, [])
        XCTAssertEqual(m.activeTopic, nil)
    }

    func testInit_loadsPersistedTopics() {
        let m = makeManager(topics: ["a", "b", "c"])
        XCTAssertEqual(m.topics, ["a", "b", "c"])
    }

    func testInit_loadsPersistedOffset() {
        let m = makeManager(topics: ["a", "b"], offset: 1)
        XCTAssertNotNil(m.activeIndex)
    }

    // MARK: - addTopic

    func testAddTopic() {
        let m = makeManager()
        m.addTopic("meditation")
        XCTAssertEqual(m.topics, ["meditation"])
    }

    func testAddTopic_trims() {
        let m = makeManager()
        m.addTopic("  spaced  ")
        XCTAssertEqual(m.topics, ["spaced"])
    }

    func testAddTopic_ignoresEmpty() {
        let m = makeManager()
        m.addTopic("")
        m.addTopic("   ")
        XCTAssertEqual(m.topics, [])
    }

    func testAddTopic_preservesActiveTopic() {
        let m = makeManager(topics: ["a", "b", "c"])
        let before = m.activeTopic
        m.addTopic("d")
        XCTAssertEqual(m.activeTopic, before)
    }

    // MARK: - removeTopic

    func testRemoveTopic() {
        let m = makeManager(topics: ["a", "b", "c"])
        m.removeTopic(at: 1)
        XCTAssertEqual(m.topics, ["a", "c"])
    }

    func testRemoveTopic_outOfBounds() {
        let m = makeManager(topics: ["a"])
        m.removeTopic(at: 5)
        XCTAssertEqual(m.topics, ["a"])
    }

    func testRemoveTopic_lastOne() {
        let m = makeManager(topics: ["only"])
        m.removeTopic(at: 0)
        XCTAssertEqual(m.topics, [])
        XCTAssertNil(m.activeTopic)
    }

    // MARK: - moveTopic

    func testMoveTopic() {
        let m = makeManager(topics: ["a", "b", "c"])
        let active = m.activeTopic
        m.moveTopic(from: IndexSet(integer: 0), to: 3)
        XCTAssertEqual(m.topics, ["b", "c", "a"])
        XCTAssertEqual(m.activeTopic, active, "Active topic should be preserved after move")
    }

    // MARK: - activate

    func testActivate() {
        let m = makeManager(topics: ["a", "b", "c"])
        m.activate(index: 2)
        XCTAssertEqual(m.activeIndex, 2)
        XCTAssertEqual(m.activeTopic, "c")
    }

    func testActivate_outOfBounds() {
        let m = makeManager(topics: ["a"])
        let before = m.activeIndex
        m.activate(index: 5)
        XCTAssertEqual(m.activeIndex, before)
    }

    // MARK: - setOffset

    func testSetOffset() {
        let m = makeManager(topics: ["a", "b", "c"])
        m.setOffset(2)
        let slot = TopicRotation.halfDaySlot()
        let expected = TopicRotation.activeIndex(slot: slot, offset: 2, count: 3)
        XCTAssertEqual(m.activeIndex, expected)
    }

    // MARK: - Persistence

    func testPersistence_writesToDefaults() {
        let defaults = freshDefaults()
        let m = TopicManager(defaults: defaults)
        tm = m
        m.addTopic("persisted")
        m.setOffset(42)

        // Verify data was written to UserDefaults
        let data = defaults.data(forKey: "topics")!
        let topics = try! JSONDecoder().decode([String].self, from: data)
        XCTAssertEqual(topics, ["persisted"])
        XCTAssertEqual(defaults.integer(forKey: "topicOffset"), 42)
    }
}
