import SwiftUI
import Combine
#if os(macOS)
import AppKit
#endif

final class AppState: ObservableObject {
    let reminderManager = ReminderManager()
    #if os(macOS)
    let vlcMonitor = VLCMonitor()
    #endif
    let topicManager = TopicManager()
    #if os(macOS)
    let forcedBreakManager = ForcedBreakManager()
    let settingsWindowController: SettingsWindowController
    let statusBarController: StatusBarController
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
        settingsWindowController = SettingsWindowController(topicManager: topicManager, reminderManager: reminderManager, peerSyncManager: sync, forcedBreakManager: forcedBreakManager)
        reminderManager.connectVLCMonitor(vlcMonitor)
        reminderManager.dropAnimationController = DropAnimationController()
        reminderManager.forcedBreakManager = forcedBreakManager
        // StatusBarController created after all dependencies are ready
        statusBarController = StatusBarController(
            reminderManager: reminderManager,
            vlcMonitor: vlcMonitor,
            topicManager: topicManager,
            peerSyncManager: sync,
            forcedBreakManager: forcedBreakManager,
            settingsWindowController: settingsWindowController
        )
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

#if os(macOS)
final class StatusBarController {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var snoozedCancellable: AnyCancellable?

    init(reminderManager: ReminderManager, vlcMonitor: VLCMonitor, topicManager: TopicManager,
         peerSyncManager: PeerSyncManager, forcedBreakManager: ForcedBreakManager,
         settingsWindowController: SettingsWindowController) {

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = BuddhaIcon.makeImage(snoozed: false)

        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView:
            SettingsView(
                reminderManager: reminderManager,
                vlcMonitor: vlcMonitor,
                topicManager: topicManager,
                peerSyncManager: peerSyncManager,
                forcedBreakManager: forcedBreakManager,
                onOpenSettings: { [weak popover, weak settingsWindowController] in
                    popover?.performClose(nil)
                    settingsWindowController?.open()
                }
            )
        )

        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self

        snoozedCancellable = reminderManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self, weak reminderManager] _ in
                guard let reminderManager = reminderManager else { return }
                self?.statusItem.button?.image = BuddhaIcon.makeImage(snoozed: reminderManager.isSnoozed)
            }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {}
}
#endif

@main
struct SatiApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    @StateObject private var appState = AppState()

    var body: some Scene {
        #if os(macOS)
        Settings {
            EmptyView()
        }
        #else
        WindowGroup {
            ContentView(appState: appState, topicManager: appState.topicManager, reminderManager: appState.reminderManager)
        }
        #endif
    }
}
