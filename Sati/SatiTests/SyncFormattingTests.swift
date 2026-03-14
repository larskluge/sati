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
        #expect(result == "Synced 1 second ago")
    }

    @Test func fifteenSecondsAgo() {
        let now = Date()
        let past = now.addingTimeInterval(-15)
        let result = SyncFormatting.relativeSyncTime(for: past, relativeTo: now)
        #expect(result == "Synced 15 seconds ago")
    }

    @Test func thirtySecondsAgo() {
        let now = Date()
        let past = now.addingTimeInterval(-30)
        let result = SyncFormatting.relativeSyncTime(for: past, relativeTo: now)
        #expect(result.hasPrefix("Synced "))
        #expect(result.contains("30 seconds ago"))
    }

    @Test func fiveMinutesAgo() {
        let now = Date()
        let past = now.addingTimeInterval(-5 * 60)
        let result = SyncFormatting.relativeSyncTime(for: past, relativeTo: now)
        #expect(result.hasPrefix("Synced "))
        #expect(result.contains("5 minutes ago"))
    }

    @Test func oneHourAgo() {
        let now = Date()
        let past = now.addingTimeInterval(-60 * 60)
        let result = SyncFormatting.relativeSyncTime(for: past, relativeTo: now)
        #expect(result.hasPrefix("Synced "))
        #expect(result.contains("hour"))
        #expect(result.contains("ago"))
    }

    @Test func usesFullStyle_notAbbreviated() {
        let now = Date()
        let past = now.addingTimeInterval(-120)
        let result = SyncFormatting.relativeSyncTime(for: past, relativeTo: now)
        // Full style says "minutes", abbreviated says "min"
        #expect(result.contains("minutes"))
        #expect(!result.contains("min ago"))
    }
}
