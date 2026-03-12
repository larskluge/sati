import SwiftUI
import AppKit
import ServiceManagement

final class SettingsWindowController {
    private var window: NSWindow?
    private let topicManager: TopicManager
    private let reminderManager: ReminderManager

    init(topicManager: TopicManager, reminderManager: ReminderManager) {
        self.topicManager = topicManager
        self.reminderManager = reminderManager
    }

    func open() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = SettingsContentView(
            topicManager: topicManager,
            reminderManager: reminderManager
        )
        let hosting = NSHostingController(rootView: contentView)

        let w = NSWindow(contentViewController: hosting)
        w.title = "Sati Settings"
        w.styleMask = [.titled, .closable]
        w.setContentSize(NSSize(width: 400, height: 500))
        w.center()
        w.isReleasedWhenClosed = false
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = w
    }
}

private struct SettingsContentView: View {
    @ObservedObject var topicManager: TopicManager
    @ObservedObject var reminderManager: ReminderManager
    @State private var newTopic = ""
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private let accentGold = Color(red: 0.769, green: 0.639, blue: 0.353)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Topics section
            Text("Topics of Investigation")
                .font(.system(size: 13, weight: .semibold))
                .padding(.bottom, 8)

            topicList

            addTopicRow
                .padding(.top, 8)

            Divider()
                .padding(.vertical, 16)

            // Sound toggle
            HStack {
                Text("Sound")
                    .font(.system(size: 13))
                Spacer()
                Toggle("", isOn: $reminderManager.soundEnabled)
                    .toggleStyle(.switch)
                    .tint(accentGold)
                    .controlSize(.small)
                    .labelsHidden()
            }
            .padding(.bottom, 12)

            // Launch at Login toggle
            HStack {
                Text("Launch at Login")
                    .font(.system(size: 13))
                Spacer()
                Toggle("", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .tint(accentGold)
                    .controlSize(.small)
                    .labelsHidden()
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
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private static let scheduleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE h:mm a"
        return f
    }()

    private var topicList: some View {
        List {
            ForEach(Array(topicManager.topics.enumerated()), id: \.offset) { index, topic in
                let isActive = index == topicManager.activeIndex
                HStack(spacing: 8) {
                    Circle()
                        .fill(isActive ? accentGold : Color.clear)
                        .frame(width: 6, height: 6)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(topic)
                            .font(.system(size: 13))

                        if let date = topicManager.scheduleDate(forIndex: index) {
                            Text(isActive ? "Now" : Self.scheduleFormatter.string(from: date))
                                .font(.system(size: 10))
                                .foregroundStyle(isActive ? accentGold : .secondary)
                        }
                    }

                    Spacer()

                    if !isActive {
                        Button(action: { topicManager.activate(index: index) }) {
                            Text("Activate")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(accentGold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(accentGold.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: { topicManager.removeTopic(at: index) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
            }
            .onMove { source, dest in
                topicManager.moveTopic(from: source, to: dest)
            }
        }
        .listStyle(.bordered)
        .frame(minHeight: 150, maxHeight: 280)
    }

    private var addTopicRow: some View {
        HStack(spacing: 8) {
            TextField("Add topic...", text: $newTopic)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .onSubmit { addTopic() }

            Button(action: addTopic) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(accentGold)
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)
            .disabled(newTopic.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func addTopic() {
        topicManager.addTopic(newTopic)
        newTopic = ""
    }
}
