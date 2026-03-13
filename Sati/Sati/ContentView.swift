#if os(iOS)
import SwiftUI

struct ContentView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var topicManager: TopicManager
    @ObservedObject var reminderManager: ReminderManager
    @State private var showingAddTopic = false
    @State private var newTopicName = ""

    private let accentGold = Color(red: 0.769, green: 0.639, blue: 0.353)
    private let activeGreen = Color(red: 0.33, green: 0.72, blue: 0.44)

    private static let syncTimeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        NavigationStack {
            List {
                Section("Topics") {
                    ForEach(Array(topicManager.topics.enumerated()), id: \.offset) { index, topic in
                        topicRow(index: index, topic: topic)
                    }
                    .onMove { source, destination in
                        topicManager.moveTopic(from: source, to: destination)
                    }
                    .onDelete { indexSet in
                        for index in indexSet.sorted().reversed() {
                            topicManager.removeTopic(at: index)
                        }
                    }
                }

                Section("Reminders") {
                    Toggle("Notifications", isOn: $reminderManager.isActive)
                    Stepper("Every \(reminderManager.intervalMinutes) min",
                            value: $reminderManager.intervalMinutes,
                            in: 1...120)
                }

                if let sync = appState.peerSyncManager {
                    Section("Sync") {
                        HStack(spacing: 10) {
                            Image(systemName: sync.peerConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                                .foregroundColor(sync.peerConnected ? activeGreen : .secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                if sync.peerConnected, let name = sync.connectedPeerName {
                                    Text(name)
                                } else {
                                    Text("No device connected")
                                        .foregroundStyle(.secondary)
                                }

                                if let syncDate = sync.lastSyncDate {
                                    Text("Synced \(Self.syncTimeFormatter.localizedString(for: syncDate, relativeTo: Date()))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("Not yet synced")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }

                            Spacer()

                            Circle()
                                .fill(sync.peerConnected ? activeGreen : Color.secondary.opacity(0.3))
                                .frame(width: 7, height: 7)
                        }
                    }
                }
            }
            .navigationTitle("Sati")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddTopic = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New Topic", isPresented: $showingAddTopic) {
                TextField("Topic name", text: $newTopicName)
                Button("Add") {
                    topicManager.addTopic(newTopicName)
                    newTopicName = ""
                }
                Button("Cancel", role: .cancel) {
                    newTopicName = ""
                }
            }
            .task {
                appState.startBackgroundServices()
            }
        }
    }

    private func topicRow(index: Int, topic: String) -> some View {
        let isActive = topicManager.activeIndex == index

        return Button {
            if !isActive {
                topicManager.activate(index: index)
            }
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(isActive ? activeGreen : Color.secondary.opacity(0.4))
                    .frame(width: 7, height: 7)

                Text(topic)
                    .foregroundStyle(.primary)

                Spacer()

                if isActive {
                    Text("Active now")
                        .font(.caption)
                        .foregroundColor(activeGreen)
                } else if let date = topicManager.scheduleDate(forIndex: index) {
                    Text(date, format: .dateTime.weekday(.abbreviated).hour().minute())
                        .font(.caption)
                        .foregroundColor(accentGold)
                }
            }
        }
        .swipeActions(edge: .leading) {
            if !isActive {
                Button("Activate") {
                    topicManager.activate(index: index)
                }
                .tint(accentGold)
            }
        }
    }
}
#endif
