import XCTest
@testable import Sati

final class TopicRotationTests: XCTestCase {

    private var calendar: Calendar { Calendar.current }

    private func date(year: Int, month: Int, day: Int, hour: Int = 0) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = hour
        return calendar.date(from: c)!
    }

    // MARK: - halfDaySlot

    func testHalfDaySlot_morningIsEven() {
        let morning = date(year: 2024, month: 1, day: 1, hour: 9)
        let slot = TopicRotation.halfDaySlot(for: morning, calendar: calendar)
        XCTAssertEqual(slot % 2, 0, "Morning slots should be even")
    }

    func testHalfDaySlot_afternoonIsOdd() {
        let afternoon = date(year: 2024, month: 1, day: 1, hour: 14)
        let slot = TopicRotation.halfDaySlot(for: afternoon, calendar: calendar)
        XCTAssertEqual(slot % 2, 1, "Afternoon slots should be odd")
    }

    func testHalfDaySlot_noonIsAfternoon() {
        let noon = date(year: 2024, month: 1, day: 1, hour: 12)
        let slot = TopicRotation.halfDaySlot(for: noon, calendar: calendar)
        XCTAssertEqual(slot % 2, 1, "Noon (12:00) should count as afternoon")
    }

    func testHalfDaySlot_elevenIsStillMorning() {
        let eleven = date(year: 2024, month: 1, day: 1, hour: 11)
        let slot = TopicRotation.halfDaySlot(for: eleven, calendar: calendar)
        XCTAssertEqual(slot % 2, 0, "11:00 should still be morning")
    }

    func testHalfDaySlot_referenceDateMorningIsZero() {
        let refMorning = date(year: 2024, month: 1, day: 1, hour: 0)
        let slot = TopicRotation.halfDaySlot(for: refMorning, calendar: calendar)
        XCTAssertEqual(slot, 0)
    }

    func testHalfDaySlot_referenceDateAfternoonIsOne() {
        let refAfternoon = date(year: 2024, month: 1, day: 1, hour: 15)
        let slot = TopicRotation.halfDaySlot(for: refAfternoon, calendar: calendar)
        XCTAssertEqual(slot, 1)
    }

    func testHalfDaySlot_nextDayMorningIsTwo() {
        let nextMorning = date(year: 2024, month: 1, day: 2, hour: 8)
        let slot = TopicRotation.halfDaySlot(for: nextMorning, calendar: calendar)
        XCTAssertEqual(slot, 2)
    }

    func testHalfDaySlot_incrementsByTwo_perDay() {
        let day1 = date(year: 2024, month: 1, day: 1, hour: 9)
        let day5 = date(year: 2024, month: 1, day: 5, hour: 9)
        let slot1 = TopicRotation.halfDaySlot(for: day1, calendar: calendar)
        let slot5 = TopicRotation.halfDaySlot(for: day5, calendar: calendar)
        XCTAssertEqual(slot5 - slot1, 8, "4 days = 8 half-day slots")
    }

    // MARK: - activeIndex

    func testActiveIndex_emptyTopics_returnsNil() {
        XCTAssertNil(TopicRotation.activeIndex(slot: 5, offset: 0, count: 0))
    }

    func testActiveIndex_singleTopic_alwaysZero() {
        for slot in 0...10 {
            XCTAssertEqual(TopicRotation.activeIndex(slot: slot, offset: 0, count: 1), 0)
        }
    }

    func testActiveIndex_rotatesThrough() {
        // 3 topics, offset 0 → slot 0→0, slot 1→1, slot 2→2, slot 3→0
        XCTAssertEqual(TopicRotation.activeIndex(slot: 0, offset: 0, count: 3), 0)
        XCTAssertEqual(TopicRotation.activeIndex(slot: 1, offset: 0, count: 3), 1)
        XCTAssertEqual(TopicRotation.activeIndex(slot: 2, offset: 0, count: 3), 2)
        XCTAssertEqual(TopicRotation.activeIndex(slot: 3, offset: 0, count: 3), 0)
    }

    func testActiveIndex_offsetShifts() {
        // offset 1 shifts: slot 0 → index 1
        XCTAssertEqual(TopicRotation.activeIndex(slot: 0, offset: 1, count: 3), 1)
        XCTAssertEqual(TopicRotation.activeIndex(slot: 0, offset: 2, count: 3), 2)
        XCTAssertEqual(TopicRotation.activeIndex(slot: 0, offset: 3, count: 3), 0)
    }

    func testActiveIndex_negativeOffset() {
        // negative offset wraps correctly
        let result = TopicRotation.activeIndex(slot: 0, offset: -1, count: 3)
        XCTAssertEqual(result, 2, "Negative offset -1 with count 3 should give index 2")
    }

    func testActiveIndex_largeOffset() {
        let result = TopicRotation.activeIndex(slot: 0, offset: 100, count: 3)
        XCTAssertEqual(result, 100 % 3)
    }

    // MARK: - offset(forDesiredIndex:)

    func testOffset_roundTrip() {
        // For any desired index, computing offset then activeIndex should return that index
        let count = 5
        for slot in 0...10 {
            for desired in 0..<count {
                let off = TopicRotation.offset(forDesiredIndex: desired, slot: slot, count: count)
                let result = TopicRotation.activeIndex(slot: slot, offset: off, count: count)
                XCTAssertEqual(result, desired, "slot=\(slot) desired=\(desired) offset=\(off)")
            }
        }
    }

    func testOffset_emptyCount_returnsZero() {
        XCTAssertEqual(TopicRotation.offset(forDesiredIndex: 0, slot: 5, count: 0), 0)
    }
}
