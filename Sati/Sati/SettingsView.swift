#if os(macOS)
import SwiftUI

struct HoverButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            label()
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.primary.opacity(isHovered ? 0.08 : 0))
                )
                .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct HoverCircleButton: View {
    let systemName: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(.primary.opacity(isHovered ? 0.12 : 0.05))
                .clipShape(Circle())
                .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct SnoozeChip: View {
    let accentGold: Color
    let accentGoldDim: Color
    let action: () -> Void
    let text: String?
    let isVLCIcon: Bool
    @State private var isHovered = false

    init(_ text: String, accentGold: Color, accentGoldDim: Color, action: @escaping () -> Void) {
        self.text = text
        self.isVLCIcon = false
        self.accentGold = accentGold
        self.accentGoldDim = accentGoldDim
        self.action = action
    }

    init(vlcIcon: Bool = true, accentGold: Color, accentGoldDim: Color, action: @escaping () -> Void) {
        self.text = nil
        self.isVLCIcon = true
        self.accentGold = accentGold
        self.accentGoldDim = accentGoldDim
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Group {
                if let text = text {
                    Text(text)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .fixedSize()
                } else if isVLCIcon {
                    VLCConeShape()
                        .fill(accentGold)
                        .frame(width: 10, height: 11)
                }
            }
            .foregroundColor(accentGold)
            .frame(height: 24)
            .padding(.horizontal, 8)
            .background(isHovered ? accentGold.opacity(0.25) : accentGoldDim)
            .clipShape(Capsule())
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct SettingsView: View {
    @ObservedObject var reminderManager: ReminderManager
    @ObservedObject var vlcMonitor: VLCMonitor
    @ObservedObject var topicManager: TopicManager
    @ObservedObject var peerSyncManager: PeerSyncManager
    var onOpenSettings: () -> Void
    @State private var intervalText: String = ""
    @State private var gearHovered = false

    private let accentGold = Color(red: 0.769, green: 0.639, blue: 0.353)
    private let accentGoldDim = Color(red: 0.769, green: 0.639, blue: 0.353).opacity(0.15)
    private let activeGreen = Color(red: 0.33, green: 0.72, blue: 0.44)

    var body: some View {
        VStack(spacing: 0) {
            // Status
            HStack(spacing: 10) {
                Circle()
                    .fill(reminderManager.isSnoozed ? Color.secondary.opacity(0.5) : activeGreen)
                    .frame(width: 7, height: 7)

                Text(reminderManager.statusText)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(reminderManager.isSnoozed ? .secondary : .primary)

                if !reminderManager.isSnoozed, let topic = topicManager.activeTopic {
                    Text("「\(topic)」")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(accentGold)
                }

                Spacer()

                if reminderManager.isSnoozed {
                    HoverButton(action: { reminderManager.resume() }) {
                        Text("Resume")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(accentGold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    }
                }

                Circle()
                    .fill(peerSyncManager.peerConnected ? activeGreen : Color.secondary.opacity(0.3))
                    .frame(width: 6, height: 6)
                    .help(peerSyncManager.peerConnected ? "Peer connected" : "No peer connected")

                Button(action: {
                    NSApp.keyWindow?.close()
                    onOpenSettings()
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(.primary.opacity(gearHovered ? 0.12 : 0.05))
                        .clipShape(Circle())
                        .animation(.easeInOut(duration: 0.15), value: gearHovered)
                }
                .buttonStyle(.plain)
                .onHover { gearHovered = $0 }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .animation(.easeInOut(duration: 0.25), value: reminderManager.isSnoozed)

            // Snooze row (when active)
            if !reminderManager.isSnoozed {
                snoozeRow(showAll: true)
            }

            // Extended snooze from notification "More..." action
            if reminderManager.showExtendedSnooze && reminderManager.isSnoozed {
                snoozeRow(showAll: false)
            }

            separator

            // Interval
            HStack(spacing: 0) {
                Text("Every")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)

                Spacer()

                HoverCircleButton(systemName: "minus") {
                    let newVal = max(1, reminderManager.intervalMinutes - 1)
                    reminderManager.intervalMinutes = newVal
                    intervalText = "\(newVal)"
                }

                TextField("", text: $intervalText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .light, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .frame(width: 36)
                    .onSubmit { applyInterval() }

                Text("min")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)

                HoverCircleButton(systemName: "plus") {
                    let newVal = min(1440, reminderManager.intervalMinutes + 1)
                    reminderManager.intervalMinutes = newVal
                    intervalText = "\(newVal)"
                }
                .padding(.leading, 6)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            separator

            // Quit
            HoverButton(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack {
                    Text("Quit")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
        }
        .frame(width: 300)
        .onAppear {
            intervalText = "\(reminderManager.intervalMinutes)"
        }
        .onChange(of: reminderManager.intervalMinutes) { _, newValue in
            intervalText = "\(newValue)"
        }
    }

    private func snoozeRow(showAll: Bool) -> some View {
        HStack(spacing: 6) {
            if showAll {
                Text("Snooze")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
                Spacer()
            }

            if showAll {
                chip("15m") { reminderManager.snooze(minutes: 15) }
                chip("30m") { reminderManager.snooze(minutes: 30) }
                chip("45m") { reminderManager.snooze(minutes: 45) }
            }
            chip("1h") { reminderManager.snooze(minutes: 60) }
            if vlcMonitor.isVLCRunning {
                SnoozeChip(vlcIcon: true, accentGold: accentGold, accentGoldDim: accentGoldDim) {
                    reminderManager.snoozeForVLC()
                    reminderManager.showExtendedSnooze = false
                }
            }
            if !showAll { Spacer() }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func chip(_ title: String, action: @escaping () -> Void) -> some View {
        SnoozeChip(title, accentGold: accentGold, accentGoldDim: accentGoldDim) {
            action()
            reminderManager.showExtendedSnooze = false
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(.primary.opacity(0.08))
            .frame(height: 1)
            .padding(.horizontal, 12)
    }

    private func applyInterval() {
        if let val = Int(intervalText), val >= 1 {
            reminderManager.intervalMinutes = val
        } else {
            intervalText = "\(reminderManager.intervalMinutes)"
        }
    }
}

// VLC traffic cone silhouette
struct VLCConeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()

        p.move(to: CGPoint(x: w * 0.35, y: h * 0.0))
        p.addLine(to: CGPoint(x: w * 0.65, y: h * 0.0))
        p.addLine(to: CGPoint(x: w * 0.80, y: h * 0.70))
        p.addLine(to: CGPoint(x: w * 0.20, y: h * 0.70))
        p.closeSubpath()

        p.addRoundedRect(
            in: CGRect(x: w * 0.05, y: h * 0.70, width: w * 0.90, height: h * 0.30),
            cornerSize: CGSize(width: h * 0.08, height: h * 0.08)
        )

        return p
    }
}
#endif
