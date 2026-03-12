#if os(macOS)
import SwiftUI
import AppKit
import ServiceManagement
import UniformTypeIdentifiers

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

        hosting.sizingOptions = .intrinsicContentSize

        let w = NSWindow(contentViewController: hosting)
        w.title = "Sati Settings"
        w.titlebarAppearsTransparent = true
        w.styleMask = [.titled, .closable, .fullSizeContentView]
        w.center()
        w.isReleasedWhenClosed = false
        w.backgroundColor = .windowBackgroundColor
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = w
    }
}

// MARK: - Main Content

private struct SettingsContentView: View {
    @ObservedObject var topicManager: TopicManager
    @ObservedObject var reminderManager: ReminderManager
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
            generalSection
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
