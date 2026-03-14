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
    #if os(iOS)
    @Published var watchConnectivitySender: WatchConnectivitySender?
    private var didStart = false
    #endif
    #if os(macOS) || os(iOS)
    @Published var peerSyncManager: PeerSyncManager?
    #endif

    init() {
        #if os(macOS)
        let sync = PeerSyncManager(topicManager: topicManager, reminderManager: reminderManager)
        peerSyncManager = sync
        settingsWindowController = SettingsWindowController(topicManager: topicManager, reminderManager: reminderManager, peerSyncManager: sync)
        reminderManager.connectVLCMonitor(vlcMonitor)
        #endif
        reminderManager.topicManager = topicManager
    }

    #if os(iOS)
    func startBackgroundServices() {
        guard !didStart else { return }
        didStart = true
        SatiLog.info("App", "starting background services")
        peerSyncManager = PeerSyncManager(topicManager: topicManager, reminderManager: reminderManager)
        watchConnectivitySender = WatchConnectivitySender(topicManager: topicManager, reminderManager: reminderManager)
        SatiLog.info("App", "background services started")
    }
    #endif
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
                peerSyncManager: appState.peerSyncManager!,
                onOpenSettings: { [weak appState] in appState?.settingsWindowController.open() }
            )
        } label: {
            Image(nsImage: BuddhaIcon.makeImage(snoozed: appState.reminderManager.isSnoozed))
        }
        .menuBarExtraStyle(.window)
        #else
        WindowGroup {
            ContentView(appState: appState, topicManager: appState.topicManager, reminderManager: appState.reminderManager)
        }
        #endif
    }
}
