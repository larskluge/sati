import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set app icon programmatically (bypasses icon cache issues)
        let iconPath = Bundle.main.bundlePath + "/Contents/Resources/AppIcon.icns"
        if let icon = NSImage(contentsOfFile: iconPath) {
            NSApplication.shared.applicationIconImage = icon
        }
    }
}

final class AppState: ObservableObject {
    let reminderManager = ReminderManager()
    let vlcMonitor = VLCMonitor()
    let topicManager = TopicManager()
    let settingsWindowController: SettingsWindowController

    init() {
        settingsWindowController = SettingsWindowController(topicManager: topicManager, reminderManager: reminderManager)
        reminderManager.topicManager = topicManager
        reminderManager.connectVLCMonitor(vlcMonitor)
    }
}

@main
struct SatiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            SettingsView(
                reminderManager: appState.reminderManager,
                vlcMonitor: appState.vlcMonitor,
                topicManager: appState.topicManager,
                onOpenSettings: { [weak appState] in appState?.settingsWindowController.open() }
            )
        } label: {
            Image(nsImage: BuddhaIcon.makeImage(snoozed: appState.reminderManager.isSnoozed))
        }
        .menuBarExtraStyle(.window)
    }
}
