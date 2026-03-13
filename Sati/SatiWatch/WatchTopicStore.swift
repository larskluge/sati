import SwiftUI
import Combine

final class WatchTopicStore: ObservableObject {
    private static let topicsKey = "watchTopics"
    private static let offsetKey = "watchTopicOffset"
    private static let referenceDate: Date = {
        var c = DateComponents()
        c.year = 2024; c.month = 1; c.day = 1
        return Calendar.current.date(from: c)!
    }()

    @Published var topics: [String] {
        didSet { save() }
    }

    var offset: Int {
        didSet { UserDefaults.standard.set(offset, forKey: Self.offsetKey) }
    }

    private var halfDaySlot: Int {
        let now = Date()
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: Self.referenceDate, to: now).day!
        return days * 2 + (cal.component(.hour, from: now) >= 12 ? 1 : 0)
    }

    var activeTopic: String? {
        guard !topics.isEmpty else { return nil }
        let index = (halfDaySlot + offset) % topics.count
        return topics[index]
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.topicsKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            self.topics = decoded
            SatiLog.info("WatchTopicStore", "init: loaded topics=\(decoded)")
        } else {
            self.topics = []
            SatiLog.info("WatchTopicStore", "init: no saved topics, starting empty")
        }
        self.offset = UserDefaults.standard.integer(forKey: Self.offsetKey)
        SatiLog.info("WatchTopicStore", "init: offset=\(offset)")
    }

    func update(topics: [String], offset: Int) {
        SatiLog.info("WatchTopicStore", "update: topics=\(topics) offset=\(offset)")
        self.topics = topics
        self.offset = offset
    }

    private func save() {
        if let data = try? JSONEncoder().encode(topics) {
            UserDefaults.standard.set(data, forKey: Self.topicsKey)
        } else {
            SatiLog.error("WatchTopicStore", "failed to encode topics")
        }
    }
}
