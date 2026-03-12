import SwiftUI
import Combine

final class TopicManager: ObservableObject {
    private static let topicsKey = "topics"
    private static let offsetKey = "topicOffset"
    private static let referenceDate: Date = {
        var c = DateComponents()
        c.year = 2024; c.month = 1; c.day = 1
        return Calendar.current.date(from: c)!
    }()

    @Published var topics: [String] {
        didSet { save() }
    }

    /// Offset added to halfDaySlot so mutations don't shift the active topic.
    private var offset: Int {
        didSet { UserDefaults.standard.set(offset, forKey: Self.offsetKey) }
    }

    private var halfDaySlot: Int {
        let now = Date()
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: Self.referenceDate, to: now).day!
        return days * 2 + (cal.component(.hour, from: now) >= 12 ? 1 : 0)
    }

    var activeIndex: Int? {
        guard !topics.isEmpty else { return nil }
        return (halfDaySlot + offset) % topics.count
    }

    var activeTopic: String? {
        guard let i = activeIndex else { return nil }
        return topics[i]
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.topicsKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            self.topics = decoded
        } else {
            self.topics = []
        }
        self.offset = UserDefaults.standard.integer(forKey: Self.offsetKey)
    }

    func addTopic(_ topic: String) {
        let trimmed = topic.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let pinned = activeIndex
        topics.append(trimmed)
        restoreActive(pinned)
    }

    func removeTopic(at index: Int) {
        guard topics.indices.contains(index) else { return }
        let pinned = activeIndex
        topics.remove(at: index)
        restoreActive(pinned == index ? nil : pinned.map({ $0 > index ? $0 - 1 : $0 }))
    }

    func moveTopic(from source: IndexSet, to destination: Int) {
        let pinned = activeIndex
        var copy = topics
        copy.move(fromOffsets: source, toOffset: destination)
        let newPinned: Int?
        if let p = pinned {
            let pinnedTopic = topics[p]
            newPinned = copy.firstIndex(of: pinnedTopic)
        } else {
            newPinned = nil
        }
        topics = copy
        restoreActive(newPinned)
    }

    func activate(index: Int) {
        guard topics.indices.contains(index) else { return }
        restoreActive(index)
        objectWillChange.send()
    }

    func scheduleDate(forIndex index: Int) -> Date? {
        guard !topics.isEmpty else { return nil }
        let count = topics.count
        let currentSlot = halfDaySlot
        let currentActive = (currentSlot + offset) % count

        let slotsAhead = ((index - currentActive) % count + count) % count
        let targetSlot = currentSlot + slotsAhead

        let cal = Calendar.current
        let days = targetSlot / 2
        let isPM = targetSlot % 2 == 1
        guard var date = cal.date(byAdding: .day, value: days, to: Self.referenceDate) else { return nil }
        if isPM {
            date = cal.date(bySettingHour: 12, minute: 0, second: 0, of: date)!
        } else {
            date = cal.startOfDay(for: date)
        }
        return date
    }

    private func restoreActive(_ desiredIndex: Int?) {
        guard !topics.isEmpty else { return }
        guard let desired = desiredIndex, topics.indices.contains(desired) else { return }
        let slot = halfDaySlot
        let count = topics.count
        offset = ((desired - slot) % count + count) % count
    }

    private func save() {
        if let data = try? JSONEncoder().encode(topics) {
            UserDefaults.standard.set(data, forKey: Self.topicsKey)
        }
    }
}
