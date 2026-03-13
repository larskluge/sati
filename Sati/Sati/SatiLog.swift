import Foundation
import os

/// Dual logger: writes to both os.Logger (for Console.app) and a ring-buffer file
/// that can be pulled from devices via `devicectl device copy from`.
///
/// Usage:  SatiLog.info("WCSender", "sent context")
///         SatiLog.error("WCRecv", "decode failed")
///
/// File location:  <AppContainer>/Documents/sati.log
/// Pull from iOS:  xcrun devicectl device copy from --device <name> \
///                   --domain-type appDataContainer --domain-identifier com.sati.Sati \
///                   --source Documents/sati.log --destination /tmp/sati-ios.log
/// Pull from watch: same with watch device name and com.sati.Sati.watchkitapp
/// macOS: ~/Library/Containers/com.sati.Sati/Data/Documents/sati.log (or direct path below)
struct SatiLog {
    private static let maxSize = 256 * 1024  // 256 KB ring buffer
    private static let osLog = Logger(subsystem: "com.sati.Sati", category: "Sati")

    private static let logURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("sati.log")
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private static let queue = DispatchQueue(label: "com.sati.log", qos: .utility)

    static func info(_ category: String, _ message: String) {
        let line = "\(dateFormatter.string(from: Date())) [\(category)] \(message)"
        osLog.info("\(category): \(message)")
        appendLine(line)
    }

    static func warning(_ category: String, _ message: String) {
        let line = "\(dateFormatter.string(from: Date())) ⚠ [\(category)] \(message)"
        osLog.warning("\(category): \(message)")
        appendLine(line)
    }

    static func error(_ category: String, _ message: String) {
        let line = "\(dateFormatter.string(from: Date())) ✗ [\(category)] \(message)"
        osLog.error("\(category): \(message)")
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

    /// Keep the last half of the file when it exceeds maxSize.
    private static func truncateLog() {
        guard let content = try? Data(contentsOf: logURL) else { return }
        let half = content.count / 2
        // Find the first newline after the halfway point to avoid splitting a line
        if let newlineIndex = content[half...].firstIndex(of: UInt8(ascii: "\n")) {
            let trimmed = content[(newlineIndex + 1)...]
            try? trimmed.write(to: logURL)
        }
    }
}
