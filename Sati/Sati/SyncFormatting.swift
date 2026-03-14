import Foundation

enum SyncFormatting {
    private static let formatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    static func relativeSyncTime(for date: Date, relativeTo now: Date = Date()) -> String {
        let elapsed = now.timeIntervalSince(date)
        if elapsed < 1 {
            return "Synced just now"
        }
        return "Synced \(formatter.localizedString(for: date, relativeTo: now))"
    }
}
