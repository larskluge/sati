import SwiftUI
import WatchKit

struct WatchSettingsView: View {
    @ObservedObject var reminderManager: WatchReminderManager

    private let hapticOptions: [(String, WKHapticType)] = [
        ("Notification", .notification),
        ("Direction Up", .directionUp),
        ("Success", .success),
        ("Click", .click),
        ("Start", .start),
        ("Retry", .retry),
    ]

    var body: some View {
        List {
            Section("Interval") {
                Stepper(
                    "Every \(reminderManager.intervalMinutes)m",
                    value: $reminderManager.intervalMinutes,
                    in: 1...1440
                )
            }

            if reminderManager.isSnoozed {
                Section {
                    Button("Resume") {
                        reminderManager.resume()
                    }
                }
            }

            Section("Haptic") {
                ForEach(hapticOptions, id: \.0) { name, type in
                    Button {
                        reminderManager.hapticType = type
                        WKInterfaceDevice.current().play(type)
                    } label: {
                        HStack {
                            Text(name)
                            Spacer()
                            if reminderManager.hapticType == type {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Settings")
    }
}
