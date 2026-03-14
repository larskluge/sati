import SwiftUI

struct WatchMainView: View {
    @ObservedObject var reminderManager: WatchReminderManager
    @ObservedObject var topicStore: WatchTopicStore
    @ObservedObject var connectivity: WatchConnectivityReceiver
    @State private var showSettings = false

    private let gold = Color(red: 0.769, green: 0.639, blue: 0.353)
    private let green = Color(red: 0.33, green: 0.72, blue: 0.44)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    statusRow

                    if let phrase = reminderManager.lastReminderPhrase {
                        Text(phrase)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                    }

                    Spacer(minLength: 8)

                    snoozeButton

                    if reminderManager.isSnoozed {
                        Button {
                            reminderManager.resume()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                Text("Resume")
                                    .font(.footnote)
                            }
                        }
                    }

                }
                .padding(.horizontal)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        WatchSettingsView(reminderManager: reminderManager, connectivity: connectivity)
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
        }
    }

    private var statusRow: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(reminderManager.isSnoozed ? Color.gray : green)
                .frame(width: 8, height: 8)
            if let minutes = reminderManager.snoozeRemainingMinutes {
                Text("Snoozed \(minutes)m")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if let topic = topicStore.activeTopic {
                Text("\u{300C}\(topic)\u{300D}")
                    .font(.footnote)
                    .foregroundStyle(gold)
            } else {
                Text("Active")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var snoozeButton: some View {
        Button {
            reminderManager.snooze()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "moon.zzz")
                if reminderManager.isSnoozed {
                    Text("+15m")
                        .font(.footnote)
                } else {
                    Text("Snooze 15m")
                        .font(.footnote)
                }
            }
        }
    }
}
