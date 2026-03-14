import Foundation

struct SyncPayload {
    let topics: [String]
    let topicOffset: Int
    let intervalMinutes: Int
    let updatedAt: Date

    func toDictionary() -> [String: Any] {
        [
            "topics": topics,
            "topicOffset": topicOffset,
            "intervalMinutes": intervalMinutes,
            "updatedAt": updatedAt.timeIntervalSince1970,
        ]
    }

    static func fromDictionary(_ dict: [String: Any]) -> SyncPayload? {
        guard let topics = dict["topics"] as? [String],
              let offset = dict["topicOffset"] as? Int,
              let interval = dict["intervalMinutes"] as? Int,
              let timestamp = dict["updatedAt"] as? Double else {
            return nil
        }
        return SyncPayload(
            topics: topics,
            topicOffset: offset,
            intervalMinutes: interval,
            updatedAt: Date(timeIntervalSince1970: timestamp)
        )
    }

    func contentHash() -> Int {
        var hasher = Hasher()
        hasher.combine(topics)
        hasher.combine(topicOffset)
        hasher.combine(intervalMinutes)
        return hasher.finalize()
    }

    func shouldReplace(_ other: SyncPayload) -> Bool {
        updatedAt > other.updatedAt
    }
}
