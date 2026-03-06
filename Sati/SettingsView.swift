import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var reminderManager: ReminderManager
    @ObservedObject var vlcMonitor: VLCMonitor
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var intervalText: String = ""

    private let bgColor = Color(red: 0.961, green: 0.953, blue: 0.941)  // #F5F3F0
    private let accentGold = Color(red: 0.769, green: 0.639, blue: 0.353)  // #C4A35A
    private let textPrimary = Color(white: 0.2)
    private let textSecondary = Color(white: 0.45)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Status
            HStack {
                Circle()
                    .fill(reminderManager.isSnoozed ? textSecondary : accentGold)
                    .frame(width: 8, height: 8)
                Text(reminderManager.statusText)
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(textPrimary)
                Spacer()
            }
            .animation(.easeInOut(duration: 0.3), value: reminderManager.isSnoozed)

            // Resume button when snoozed
            if reminderManager.isSnoozed {
                Button(action: { reminderManager.resume() }) {
                    Text("Resume")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(accentGold)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            // Extended snooze options (shown when "More..." tapped on notification)
            if reminderManager.showExtendedSnooze {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Snooze for...")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(textSecondary)

                    HStack(spacing: 8) {
                        snoozeButton("1 hour") { reminderManager.snooze(minutes: 60) }
                        snoozeButton("2 hours") { reminderManager.snooze(minutes: 120) }
                        if vlcMonitor.isVLCRunning {
                            snoozeButton("While VLC") { reminderManager.snoozeForVLC() }
                        }
                    }
                }
                .transition(.opacity)
            }

            Divider()

            // Interval
            HStack {
                Text("Interval")
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(textPrimary)
                Spacer()
                TextField("", text: $intervalText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .light))
                    .frame(width: 40)
                    .multilineTextAlignment(.trailing)
                    .onSubmit { applyInterval() }
                Text("min")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(textSecondary)
                Stepper("", value: Binding(
                    get: { reminderManager.intervalMinutes },
                    set: {
                        reminderManager.intervalMinutes = max(1, $0)
                        intervalText = "\(reminderManager.intervalMinutes)"
                    }
                ), in: 1...1440)
                .labelsHidden()
            }

            Divider()

            // Launch at Login
            Toggle(isOn: $launchAtLogin) {
                Text("Launch at Login")
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(textPrimary)
            }
            .toggleStyle(.switch)
            .tint(accentGold)
            .onChange(of: launchAtLogin) { newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    print("Launch at login error: \(error)")
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }
            }

            Divider()

            // Quit
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Text("Quit Sati")
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(width: 280)
        .background(bgColor)
        .onAppear {
            intervalText = "\(reminderManager.intervalMinutes)"
            reminderManager.showExtendedSnooze = false
        }
    }

    private func snoozeButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            reminderManager.showExtendedSnooze = false
        }) {
            Text(title)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(white: 0.9))
                .cornerRadius(5)
        }
        .buttonStyle(.plain)
    }

    private func applyInterval() {
        if let val = Int(intervalText), val >= 1 {
            reminderManager.intervalMinutes = val
        } else {
            intervalText = "\(reminderManager.intervalMinutes)"
        }
    }
}
