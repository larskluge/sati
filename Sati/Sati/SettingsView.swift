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
    @ObservedObject var forcedBreakManager: ForcedBreakManager
    var onOpenSettings: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var gearHovered = false
    @State private var showPauseOptions = false

    private let accentGold = Color(red: 0.769, green: 0.639, blue: 0.353)
    private let accentGoldDim = Color(red: 0.769, green: 0.639, blue: 0.353).opacity(0.15)
    private let activeGreen = Color(red: 0.33, green: 0.72, blue: 0.44)

    var body: some View {
        VStack(spacing: 0) {
            // Status + actions row
            HStack(spacing: 10) {
                Circle()
                    .fill(reminderManager.isSnoozed ? Color.secondary.opacity(0.5) : activeGreen)
                    .frame(width: 7, height: 7)

                if reminderManager.isSnoozed {
                    Text(reminderManager.statusText)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)

                    Spacer()

                    HoverButton(action: { reminderManager.resume() }) {
                        Text("Resume")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(accentGold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                    }
                } else {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showPauseOptions.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text("Pause")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.tertiary)
                                .rotationEffect(.degrees(showPauseOptions ? 90 : 0))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button(action: {
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
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Pause duration chips
            if showPauseOptions && !reminderManager.isSnoozed {
                HStack(spacing: 6) {
                    chip("15m") { reminderManager.snooze(minutes: 15) }
                    chip("30m") { reminderManager.snooze(minutes: 30) }
                    chip("45m") { reminderManager.snooze(minutes: 45) }
                    chip("1h") { reminderManager.snooze(minutes: 60) }
                    if vlcMonitor.isVLCRunning {
                        SnoozeChip(vlcIcon: true, accentGold: accentGold, accentGoldDim: accentGoldDim) {
                            reminderManager.snoozeForVLC()
                            reminderManager.showExtendedSnooze = false
                            dismiss()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Extended snooze from notification "More..." action
            if reminderManager.showExtendedSnooze && reminderManager.isSnoozed {
                extendedSnoozeRow
            }

            // Topic
            if let topic = topicManager.activeTopic {
                Text("「\(topic)」")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(accentGold)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18)
                    .padding(.bottom, 36)
            }

            // Break progress
            if forcedBreakManager.breakEnabled {
                breakSection
            }
        }
        .padding(.bottom, 14)
        .frame(width: 320)
    }

    // MARK: - Break Section

    private var breakProgress: Double {
        let total = Double(forcedBreakManager.workDurationMinutes * 60)
        guard total > 0 else { return 0 }
        let elapsed = total - Double(forcedBreakManager.workSecondsRemaining)
        return min(1, max(0, elapsed / total))
    }

    private var breakCountdownText: String {
        let secs = forcedBreakManager.workSecondsRemaining
        let m = secs / 60
        let s = secs % 60
        return "\(m):\(String(format: "%02d", s))"
    }

    private var breakSection: some View {
        VStack(spacing: 0) {
            switch forcedBreakManager.phase {
            case .work:
                VStack(spacing: 14) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.primary.opacity(0.06))
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(accentGold.opacity(0.5))
                                .frame(width: geo.size.width * breakProgress, height: 6)
                        }
                    }
                    .frame(height: 6)

                    HStack {
                        Text("Break in \(breakCountdownText)")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Spacer()
                        SnoozeChip("Break Now", accentGold: accentGold, accentGoldDim: accentGoldDim) {
                            NSApp.keyWindow?.close()
                            forcedBreakManager.startBreak()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

            case .finishUp:
                VStack(spacing: 10) {
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(accentGold.opacity(0.5))
                            .frame(height: 6)
                    }
                    .frame(height: 6)

                    HStack {
                        Text("Time for a break")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.secondary)
                        Spacer()
                        SnoozeChip("+2 min", accentGold: accentGold, accentGoldDim: accentGoldDim) {
                            forcedBreakManager.snooze()
                            dismiss()
                        }
                        SnoozeChip("Start Break", accentGold: accentGold, accentGoldDim: accentGoldDim) {
                            NSApp.keyWindow?.close()
                            forcedBreakManager.startBreak()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

            case .snoozed:
                HStack {
                    Text("Break snoozed")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                    Spacer()
                    SnoozeChip("Start Break", accentGold: accentGold, accentGoldDim: accentGoldDim) {
                        NSApp.keyWindow?.close()
                        forcedBreakManager.startBreak()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

            case .onBreak:
                HStack {
                    Text("On break")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

            case .breakOver:
                HStack {
                    Text("Break over")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

            case .disabled:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: forcedBreakManager.phase == .finishUp)
    }

    private var extendedSnoozeRow: some View {
        HStack(spacing: 6) {
            chip("1h") { reminderManager.snooze(minutes: 60) }
            if vlcMonitor.isVLCRunning {
                SnoozeChip(vlcIcon: true, accentGold: accentGold, accentGoldDim: accentGoldDim) {
                    reminderManager.snoozeForVLC()
                    reminderManager.showExtendedSnooze = false
                    dismiss()
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Helpers

    private func chip(_ title: String, action: @escaping () -> Void) -> some View {
        SnoozeChip(title, accentGold: accentGold, accentGoldDim: accentGoldDim) {
            action()
            reminderManager.showExtendedSnooze = false
            dismiss()
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(.primary.opacity(0.08))
            .frame(height: 1)
            .padding(.horizontal, 16)
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
