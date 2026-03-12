import SwiftUI

struct WatchMainView: View {
    @ObservedObject var reminderManager: WatchReminderManager
    @ObservedObject var topicStore: WatchTopicStore
    @State private var showSettings = false

    private let gold = Color(red: 0.769, green: 0.639, blue: 0.353)
    private let green = Color(red: 0.33, green: 0.72, blue: 0.44)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    statusRow

                    if let topic = topicStore.activeTopic {
                        Text("\u{300C}\(topic)\u{300D}")
                            .font(.body)
                            .foregroundStyle(gold)
                            .multilineTextAlignment(.center)
                    }

                    if let phrase = reminderManager.lastReminderPhrase {
                        Text(phrase)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                    }

                    Spacer(minLength: 8)

                    snoozeButton

                    NavigationLink {
                        WatchSettingsView(reminderManager: reminderManager)
                    } label: {
                        Image(systemName: "gear")
                            .font(.body)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var statusRow: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(reminderManager.isSnoozed ? Color.gray : green)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var statusText: String {
        if let minutes = reminderManager.snoozeRemainingMinutes {
            return "Snoozed \(minutes)m"
        }
        return "Active"
    }

    private var snoozeButton: some View {
        Button {
            reminderManager.snooze()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "moon.zzz")
                if let minutes = reminderManager.snoozeRemainingMinutes {
                    Text("+15m (\(minutes)m)")
                        .font(.footnote)
                } else {
                    Text("Snooze 15m")
                        .font(.footnote)
                }
            }
        }
    }
}
