import Foundation

struct WatchContext: Equatable {
    let topics: [String]
    let topicOffset: Int
    let intervalMinutes: Int
}

enum WatchContextCoder {
    static func encode(_ context: WatchContext) -> [String: Any]? {
        guard let topicsData = try? JSONEncoder().encode(context.topics) else {
            return nil
        }
        return [
            "topics": topicsData,
            "topicOffset": context.topicOffset,
            "intervalMinutes": context.intervalMinutes,
        ]
    }

    static func decode(_ dict: [String: Any]) -> WatchContext? {
        let topics: [String]?
        if let data = dict["topics"] as? Data {
            topics = try? JSONDecoder().decode([String].self, from: data)
        } else if let array = dict["topics"] as? [String] {
            topics = array
        } else {
            topics = nil
        }

        guard let topics,
              let offset = dict["topicOffset"] as? Int,
              let interval = dict["intervalMinutes"] as? Int else {
            return nil
        }

        return WatchContext(topics: topics, topicOffset: offset, intervalMinutes: interval)
    }
}
