import Foundation

struct TopicRotation {
    static let referenceDate: Date = {
        var c = DateComponents()
        c.year = 2024; c.month = 1; c.day = 1
        return Calendar.current.date(from: c)!
    }()

    static func halfDaySlot(for date: Date = Date(), calendar: Calendar = .current) -> Int {
        let days = calendar.dateComponents([.day], from: referenceDate, to: date).day!
        return days * 2 + (calendar.component(.hour, from: date) >= 12 ? 1 : 0)
    }

    static func activeIndex(slot: Int, offset: Int, count: Int) -> Int? {
        guard count > 0 else { return nil }
        return ((slot + offset) % count + count) % count
    }

    static func offset(forDesiredIndex index: Int, slot: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return ((index - slot) % count + count) % count
    }
}
