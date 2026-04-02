#if os(macOS)
import SwiftUI
import AppKit
import ServiceManagement
import UniformTypeIdentifiers

final class SettingsWindowController {
    private var window: NSWindow?
    private let topicManager: TopicManager
    private let reminderManager: ReminderManager
    private let peerSyncManager: PeerSyncManager
    private let forcedBreakManager: ForcedBreakManager

    init(topicManager: TopicManager, reminderManager: ReminderManager, peerSyncManager: PeerSyncManager, forcedBreakManager: ForcedBreakManager) {
        self.topicManager = topicManager
        self.reminderManager = reminderManager
        self.peerSyncManager = peerSyncManager
        self.forcedBreakManager = forcedBreakManager
    }

    func open() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = SettingsContentView(
            topicManager: topicManager,
            reminderManager: reminderManager,
            peerSyncManager: peerSyncManager,
            forcedBreakManager: forcedBreakManager
        )
        let hosting = NSHostingController(rootView: contentView)

        hosting.sizingOptions = .intrinsicContentSize

        let w = NSWindow(contentViewController: hosting)
        w.title = "Sati Settings"
        w.titlebarAppearsTransparent = true
        w.styleMask = [.titled, .closable, .fullSizeContentView]
        w.isReleasedWhenClosed = false
        w.backgroundColor = .windowBackgroundColor
        w.makeKeyAndOrderFront(nil)
        if let screen = w.screen ?? NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - w.frame.width / 2
            let y = screenFrame.maxY - w.frame.height - 40
            w.setFrameOrigin(NSPoint(x: x, y: y))
        }
        NSApp.activate(ignoringOtherApps: true)
        self.window = w
    }
}

// MARK: - Main Content

private struct SettingsContentView: View {
    @ObservedObject var topicManager: TopicManager
    @ObservedObject var reminderManager: ReminderManager
    @ObservedObject var peerSyncManager: PeerSyncManager
    @ObservedObject var forcedBreakManager: ForcedBreakManager
    @State private var newTopic = ""
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var hoveredTopicIndex: Int? = nil
    @State private var isAddingTopic = false
    @State private var addFieldFocused = false
    @State private var draggingIndex: Int? = nil

    private let accentGold = Color(red: 0.769, green: 0.639, blue: 0.353)
    private let activeGreen = Color(red: 0.33, green: 0.72, blue: 0.44)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer().frame(height: 8)

            topicsSection
            breakSection
            generalSection
            syncSection
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .frame(width: 460)
    }

    // MARK: - Topics Section

    private var topicsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Topics of Investigation")

            GroupBox {
                VStack(spacing: 0) {
                    if topicManager.topics.isEmpty {
                        emptyTopicsPlaceholder
                    } else {
                        ForEach(Array(topicManager.topics.enumerated()), id: \.offset) { index, topic in
                            if index > 0 {
                                Divider().padding(.leading, 40)
                            }
                            topicRow(index: index, topic: topic)
                                .onDrag {
                                    draggingIndex = index
                                    return NSItemProvider(object: String(index) as NSString)
                                }
                                .onDrop(of: [.text], delegate: TopicDropDelegate(
                                    targetIndex: index,
                                    draggingIndex: $draggingIndex,
                                    topicManager: topicManager
                                ))
                        }
                    }

                    if !topicManager.topics.isEmpty {
                        Divider().padding(.leading, 40)
                    }

                    addTopicRow
                }
                .padding(.vertical, 2)
            }
            .groupBoxStyle(SettingsGroupBoxStyle())
        }
    }

    private var emptyTopicsPlaceholder: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "eye.trianglebadge.exclamationmark")
                    .font(.system(size: 20))
                    .foregroundStyle(.tertiary)
                Text("No topics yet")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 16)
            Spacer()
        }
    }

    private static let scheduleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE h:mm a"
        return f
    }()

    private func topicRow(index: Int, topic: String) -> some View {
        let isActive = index == topicManager.activeIndex
        let isHovered = hoveredTopicIndex == index

        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(isActive ? activeGreen.opacity(0.15) : .primary.opacity(0.04))
                    .frame(width: 28, height: 28)
                Circle()
                    .fill(isActive ? activeGreen : .secondary.opacity(0.3))
                    .frame(width: 7, height: 7)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(topic)
                    .font(.system(size: 13))
                    .lineLimit(1)

                if let date = topicManager.scheduleDate(forIndex: index) {
                    Text(isActive ? "Active now" : Self.scheduleFormatter.string(from: date))
                        .font(.system(size: 11))
                        .foregroundStyle(isActive ? activeGreen : .secondary)
                }
            }

            Spacer()

            if isHovered {
                if !isActive {
                    Button(action: { topicManager.activate(index: index) }) {
                        Text("Activate")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(accentGold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(accentGold.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }

                Button(action: { topicManager.removeTopic(at: index) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(isHovered ? 0.03 : 0))
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredTopicIndex = hovering ? index : nil
            }
        }
    }

    private var addTopicRow: some View {
        Group {
            if isAddingTopic {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(.primary.opacity(0.04))
                            .frame(width: 28, height: 28)
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    FocusableTextField(
                        text: $newTopic,
                        isFocused: $addFieldFocused,
                        placeholder: "Topic name...",
                        onSubmit: { addTopic() }
                    )
                    .font(.system(size: 13))

                    Button(action: {
                        newTopic = ""
                        isAddingTopic = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            } else {
                Button(action: {
                    isAddingTopic = true
                    addFieldFocused = true
                }) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(.primary.opacity(0.04))
                                .frame(width: 28, height: 28)
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        Text("Add topic...")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Break Section

    @State private var workDurationText: String = ""
    @State private var breakDurationText: String = ""

    private var breakSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Forced Break")

            GroupBox {
                VStack(spacing: 0) {
                    settingsToggleRow(
                        icon: "cup.and.saucer",
                        iconColor: accentGold,
                        title: "Forced Break",
                        subtitle: "Remind to take breaks",
                        isOn: Binding(
                            get: { forcedBreakManager.breakEnabled },
                            set: { forcedBreakManager.setEnabled($0) }
                        )
                    )

                    if forcedBreakManager.breakEnabled {
                        Divider().padding(.leading, 40)

                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "deskclock")
                                    .font(.system(size: 13))
                                    .foregroundColor(.blue)
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text("Work Duration")
                                    .font(.system(size: 13))
                                Text("Time before break reminder")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            HoverCircleButton(systemName: "minus") {
                                let current = forcedBreakManager.workDurationMinutes
                                let newVal = max(1, current - (current % 5 == 0 ? 5 : current % 5))
                                forcedBreakManager.workDurationMinutes = newVal
                                workDurationText = "\(newVal)"
                            }

                            TextField("", text: $workDurationText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 15, weight: .light, design: .rounded))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .frame(width: 36)
                                .onSubmit {
                                    if let val = Int(workDurationText), val >= 1 {
                                        forcedBreakManager.workDurationMinutes = val
                                    } else {
                                        workDurationText = "\(forcedBreakManager.workDurationMinutes)"
                                    }
                                }

                            Text("min")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(.secondary)

                            HoverCircleButton(systemName: "plus") {
                                let current = forcedBreakManager.workDurationMinutes
                                let remainder = current % 5
                                let newVal = min(120, current + (remainder == 0 ? 5 : 5 - remainder))
                                forcedBreakManager.workDurationMinutes = newVal
                                workDurationText = "\(newVal)"
                            }
                            .padding(.leading, 6)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                        Divider().padding(.leading, 40)

                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.green.opacity(0.15))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "leaf")
                                    .font(.system(size: 13))
                                    .foregroundColor(.green)
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text("Break Duration")
                                    .font(.system(size: 13))
                                Text("Length of break")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            HoverCircleButton(systemName: "minus") {
                                let newVal = max(1, forcedBreakManager.breakDurationMinutes - 1)
                                forcedBreakManager.breakDurationMinutes = newVal
                                breakDurationText = "\(newVal)"
                            }

                            TextField("", text: $breakDurationText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 15, weight: .light, design: .rounded))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .frame(width: 36)
                                .onSubmit {
                                    if let val = Int(breakDurationText), val >= 1 {
                                        forcedBreakManager.breakDurationMinutes = val
                                    } else {
                                        breakDurationText = "\(forcedBreakManager.breakDurationMinutes)"
                                    }
                                }

                            Text("min")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(.secondary)

                            HoverCircleButton(systemName: "plus") {
                                let newVal = min(30, forcedBreakManager.breakDurationMinutes + 1)
                                forcedBreakManager.breakDurationMinutes = newVal
                                breakDurationText = "\(newVal)"
                            }
                            .padding(.leading, 6)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                }
                .padding(.vertical, 2)
            }
            .groupBoxStyle(SettingsGroupBoxStyle())
        }
        .onAppear {
            workDurationText = "\(forcedBreakManager.workDurationMinutes)"
            breakDurationText = "\(forcedBreakManager.breakDurationMinutes)"
        }
        .onChange(of: forcedBreakManager.workDurationMinutes) { _, newValue in
            workDurationText = "\(newValue)"
        }
        .onChange(of: forcedBreakManager.breakDurationMinutes) { _, newValue in
            breakDurationText = "\(newValue)"
        }
    }

    // MARK: - General Section

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("General")

            GroupBox {
                VStack(spacing: 0) {
                    settingsToggleRow(
                        icon: "speaker.wave.2",
                        iconColor: .pink,
                        title: "Notification Sound",
                        subtitle: "Play singing bowl",
                        isOn: $reminderManager.soundEnabled
                    )

                    Divider().padding(.leading, 40)

                    settingsToggleRow(
                        icon: "sunrise",
                        iconColor: .orange,
                        title: "Launch at Login",
                        subtitle: "Start automatically",
                        isOn: $launchAtLogin
                    )
                    .onChange(of: launchAtLogin) { oldValue, newValue in
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
                .padding(.vertical, 2)
            }
            .groupBoxStyle(SettingsGroupBoxStyle())
        }
    }

    private func settingsToggleRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .tint(accentGold)
                .controlSize(.small)
                .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Sync Section


    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Sync")

            GroupBox {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(peerSyncManager.peerConnected ? activeGreen.opacity(0.15) : .primary.opacity(0.04))
                            .frame(width: 28, height: 28)
                        Image(systemName: peerSyncManager.peerConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 13))
                            .foregroundColor(peerSyncManager.peerConnected ? activeGreen : .secondary)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        if peerSyncManager.peerConnected, let name = peerSyncManager.connectedPeerName {
                            Text(name)
                                .font(.system(size: 13))
                        } else {
                            Text("No device connected")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }

                        if let syncDate = peerSyncManager.lastSyncDate {
                            Text(SyncFormatting.relativeSyncTime(for: syncDate))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Not yet synced")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    Circle()
                        .fill(peerSyncManager.peerConnected ? activeGreen : .secondary.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .groupBoxStyle(SettingsGroupBoxStyle())
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }

    private func addTopic() {
        topicManager.addTopic(newTopic)
        newTopic = ""
        isAddingTopic = false
    }
}

// MARK: - Drag & Drop Reorder

private struct TopicDropDelegate: DropDelegate {
    let targetIndex: Int
    @Binding var draggingIndex: Int?
    let topicManager: TopicManager

    func dropEntered(info: DropInfo) {
        guard let from = draggingIndex, from != targetIndex else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            topicManager.moveTopic(from: IndexSet(integer: from), to: targetIndex > from ? targetIndex + 1 : targetIndex)
        }
        draggingIndex = targetIndex
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingIndex = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// MARK: - Auto-focusing TextField

private struct FocusableTextField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var placeholder: String
    var onSubmit: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField()
        tf.placeholderString = placeholder
        tf.isBordered = true
        tf.bezelStyle = .roundedBezel
        tf.delegate = context.coordinator
        tf.font = .systemFont(ofSize: 13)
        return tf
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
        if isFocused {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
                isFocused = false
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: FocusableTextField
        init(_ parent: FocusableTextField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            if let tf = obj.object as? NSTextField {
                parent.text = tf.stringValue
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy sel: Selector) -> Bool {
            if sel == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            return false
        }
    }
}

// MARK: - Custom GroupBox Style

private struct SettingsGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.content
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.primary.opacity(0.04))
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
#endif
