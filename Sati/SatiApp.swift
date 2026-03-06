import SwiftUI

final class AppState: ObservableObject {
    let reminderManager = ReminderManager()
    let vlcMonitor = VLCMonitor()

    init() {
        reminderManager.connectVLCMonitor(vlcMonitor)
    }
}

@main
struct SatiApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            SettingsView(
                reminderManager: appState.reminderManager,
                vlcMonitor: appState.vlcMonitor
            )
        } label: {
            Image(nsImage: BuddhaIcon.makeImage(snoozed: appState.reminderManager.isSnoozed))
        }
        .menuBarExtraStyle(.window)
    }
}
