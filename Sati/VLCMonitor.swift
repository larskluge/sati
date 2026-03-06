import Foundation
import AppKit
import Combine

final class VLCMonitor: ObservableObject {
    @Published var isVLCRunning: Bool = false

    private var timer: Timer?

    init() {
        checkVLC()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkVLC()
        }
    }

    deinit {
        timer?.invalidate()
    }

    private func checkVLC() {
        let running = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "org.videolan.vlc"
        }
        if running != isVLCRunning {
            DispatchQueue.main.async {
                self.isVLCRunning = running
            }
        }
    }
}
