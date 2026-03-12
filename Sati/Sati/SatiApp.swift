import SwiftUI
import Combine
#if os(macOS)
import AppKit
#endif

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let iconPath = Bundle.main.bundlePath + "/Contents/Resources/AppIcon.icns"
        if let icon = NSImage(contentsOfFile: iconPath) {
            NSApplication.shared.applicationIconImage = icon
        }
    }
}
#endif

final class AppState: ObservableObject {
    let reminderManager = ReminderManager()
    #if os(macOS)
    let vlcMonitor = VLCMonitor()
    #endif
    let topicManager = TopicManager()
    #if os(macOS)
    let settingsWindowController: SettingsWindowController
    #endif

    init() {
        #if os(macOS)
        settingsWindowController = SettingsWindowController(topicManager: topicManager, reminderManager: reminderManager)
        reminderManager.connectVLCMonitor(vlcMonitor)
        #endif
        reminderManager.topicManager = topicManager
    }
}

@main
struct SatiApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    @StateObject private var appState = AppState()

    var body: some Scene {
        #if os(macOS)
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
        #else
        WindowGroup {
            ContentView()
        }
        #endif
    }
}
