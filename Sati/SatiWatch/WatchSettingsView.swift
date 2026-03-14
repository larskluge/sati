import SwiftUI
import WatchKit

struct WatchSettingsView: View {
    @ObservedObject var reminderManager: WatchReminderManager
    @ObservedObject var connectivity: WatchConnectivityReceiver

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
                HStack {
                    Button {
                        if reminderManager.intervalMinutes > 1 {
                            reminderManager.intervalMinutes -= 1
                        }
                    } label: {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                    Text("Every \(reminderManager.intervalMinutes)m")
                        .font(.body)
                    Spacer()

                    Button {
                        if reminderManager.intervalMinutes < 1440 {
                            reminderManager.intervalMinutes += 1
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.bordered)
                }
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
            Section("Sync") {
                HStack(spacing: 8) {
                    Image(systemName: "iphone")
                        .foregroundColor(connectivity.isActivated ? green : .secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(connectivity.isActivated ? "iPhone connected" : "Not connected")
                            .font(.footnote)

                        if let syncDate = connectivity.lastReceivedDate {
                            Text("Synced \(Self.syncFormatter.localizedString(for: syncDate, relativeTo: Date()))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Not yet synced")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    Circle()
                        .fill(connectivity.isActivated ? green : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .navigationTitle("Settings")
    }

    private let green = Color(red: 0.33, green: 0.72, blue: 0.44)

    private static let syncFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
}
