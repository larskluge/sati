import Foundation
import Testing
@testable import Sati

@MainActor
struct SyncFormattingTests {

    @Test func justNow() {
        let now = Date()
        let result = SyncFormatting.relativeSyncTime(for: now, relativeTo: now)
        #expect(result == "Synced just now")
    }

    @Test func oneSecondAgo() {
        let now = Date()
        let past = now.addingTimeInterval(-1)
        let result = SyncFormatting.relativeSyncTime(for: past, relativeTo: now)
        #expect(result == "Synced 1s ago")
    }

    @Test func fifteenSecondsAgo() {
        let now = Date()
        let past = now.addingTimeInterval(-15)
        let result = SyncFormatting.relativeSyncTime(for: past, relativeTo: now)
        #expect(result == "Synced 15s ago")
    }

    @Test func fiveMinutesAgo() {
        let now = Date()
        let past = now.addingTimeInterval(-5 * 60)
        let result = SyncFormatting.relativeSyncTime(for: past, relativeTo: now)
        #expect(result == "Synced 5m ago")
    }

    @Test func oneHourAgo() {
        let now = Date()
        let past = now.addingTimeInterval(-60 * 60)
        let result = SyncFormatting.relativeSyncTime(for: past, relativeTo: now)
        #expect(result == "Synced 1h ago")
    }

    @Test func usesAbbreviatedStyle() {
        let now = Date()
        let past = now.addingTimeInterval(-120)
        let result = SyncFormatting.relativeSyncTime(for: past, relativeTo: now)
        #expect(result == "Synced 2m ago")
    }
}
