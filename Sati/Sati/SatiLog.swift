import Foundation
import os

struct SatiLog {
    private static let maxSize = 256 * 1024
    private static let osLog = Logger(subsystem: "com.sati.Sati", category: "Sati")

    private static let logURL: URL = {
        let fm = FileManager.default
        #if os(macOS)
        let library = fm.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let dir = library.appendingPathComponent("Logs/Sati", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("sati.jsonl")
        #else
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("sati.jsonl")
        #endif
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let queue = DispatchQueue(label: "com.sati.log", qos: .utility)

    static func info(_ category: String, _ message: String, extra: [(String, String)] = []) {
        osLog.info("\(category): \(message)")
        appendJSON(level: "info", category: category, message: message, extra: extra)
    }

    static func warning(_ category: String, _ message: String) {
        osLog.warning("\(category): \(message)")
        appendJSON(level: "warning", category: category, message: message)
    }

    static func error(_ category: String, _ message: String) {
        osLog.error("\(category): \(message)")
        appendJSON(level: "error", category: category, message: message)
    }

    private static func appendJSON(level: String, category: String, message: String, extra: [(String, String)] = []) {
        let ts = isoFormatter.string(from: Date())
        let escaped = message
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        var line = "{\"t\":\"\(ts)\",\"l\":\"\(level)\",\"c\":\"\(category)\",\"m\":\"\(escaped)\""
        for (key, value) in extra {
            let escapedValue = value
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            line += ",\"\(key)\":\"\(escapedValue)\""
        }
        line += "}"
        appendLine(line)
    }

    private static func appendLine(_ line: String) {
        queue.async {
            let data = (line + "\n").data(using: .utf8)!
            if FileManager.default.fileExists(atPath: logURL.path) {
                if let handle = try? FileHandle(forWritingTo: logURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    let size = handle.offsetInFile
                    handle.closeFile()
                    if size > maxSize {
                        truncateLog()
                    }
                }
            } else {
                try? data.write(to: logURL)
            }
        }
    }

    private static func truncateLog() {
        guard let content = try? Data(contentsOf: logURL) else { return }
        let half = content.count / 2
        if let newlineIndex = content[half...].firstIndex(of: UInt8(ascii: "\n")) {
            let trimmed = content[(newlineIndex + 1)...]
            try? trimmed.write(to: logURL)
        }
    }
}
