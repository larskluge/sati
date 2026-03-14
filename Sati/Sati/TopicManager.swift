import SwiftUI
import Combine

final class TopicManager: ObservableObject {
    private static let topicsKey = "topics"
    private static let offsetKey = "topicOffset"

    private let defaults: UserDefaults

    @Published var topics: [String] {
        didSet { save() }
    }

    /// Offset added to halfDaySlot so mutations don't shift the active topic.
    @Published private(set) var offset: Int {
        didSet { defaults.set(offset, forKey: Self.offsetKey) }
    }

    private var halfDaySlot: Int {
        TopicRotation.halfDaySlot()
    }

    var activeIndex: Int? {
        TopicRotation.activeIndex(slot: halfDaySlot, offset: offset, count: topics.count)
    }

    var activeTopic: String? {
        guard let i = activeIndex else { return nil }
        return topics[i]
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.topicsKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            self.topics = decoded
        } else {
            self.topics = []
        }
        self.offset = defaults.integer(forKey: Self.offsetKey)
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

    func setOffset(_ newOffset: Int) {
        offset = newOffset
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
        guard let currentActive = TopicRotation.activeIndex(slot: currentSlot, offset: offset, count: count) else { return nil }

        let slotsAhead = ((index - currentActive) % count + count) % count
        let targetSlot = currentSlot + slotsAhead

        let cal = Calendar.current
        let days = targetSlot / 2
        let isPM = targetSlot % 2 == 1
        guard var date = cal.date(byAdding: .day, value: days, to: TopicRotation.referenceDate) else { return nil }
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
        offset = TopicRotation.offset(forDesiredIndex: desired, slot: halfDaySlot, count: topics.count)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(topics) {
            defaults.set(data, forKey: Self.topicsKey)
        }
    }
}
