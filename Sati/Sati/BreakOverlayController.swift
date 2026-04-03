#if os(macOS)
import SwiftUI
import AppKit
import Combine
import CoreAudio
import AudioToolbox

private class KeyableWindow: NSWindow {
    var onEscape: (() -> Void)?
    var anyKeyDismisses = false

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if anyKeyDismisses || event.keyCode == 53 {
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }
}

final class BreakOverlayController {
    private var window: KeyableWindow?
    private var hostingController: NSHostingController<BreakCountdownView>?
    private var onDismiss: (() -> Void)?
    private var viewModel = BreakViewModel()
    private var mouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var cursorHideTimer: Timer?
    private var cursorHidden = false

    func show(seconds: Int, breakSoundEnabled: Bool, onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        viewModel.secondsRemaining = seconds
        viewModel.breakOver = false
        viewModel.overtimeSeconds = 0
        if breakSoundEnabled {
            viewModel.startVolumeMonitoring()
        }

        guard let screen = NSScreen.main else { return }

        let view = BreakCountdownView(viewModel: viewModel, onEndBreak: { [weak self] in
            self?.onDismiss?()
        })

        let hosting = NSHostingController(rootView: view)
        hosting.sizingOptions = []
        let w = KeyableWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        w.isOpaque = false
        w.backgroundColor = .clear
        w.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        w.hasShadow = false
        w.contentView = hosting.view
        hosting.view.frame = NSRect(origin: .zero, size: screen.frame.size)
        w.onEscape = { [weak self] in
            self?.onDismiss?()
        }

        w.alphaValue = 0
        w.orderFrontRegardless()
        w.makeKey()
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            w.animator().alphaValue = 1.0
        }

        self.window = w
        self.hostingController = hosting
        startCursorTracking()
    }

    private func startCursorTracking() {
        scheduleCursorHide()
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] _ in
            self?.showCursor()
            self?.scheduleCursorHide()
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            self?.showCursor()
            self?.scheduleCursorHide()
            return event
        }
    }

    private func scheduleCursorHide() {
        cursorHideTimer?.invalidate()
        cursorHideTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.hideCursor()
        }
    }

    private func hideCursor() {
        guard !cursorHidden else { return }
        NSCursor.hide()
        cursorHidden = true
    }

    private func showCursor() {
        guard cursorHidden else { return }
        NSCursor.unhide()
        cursorHidden = false
    }

    func updateTime(_ seconds: Int) {
        viewModel.secondsRemaining = max(0, seconds)
    }

    func showBreakOver(breakDurationMinutes: Int) {
        viewModel.breakOver = true
        viewModel.breakDurationMinutes = breakDurationMinutes
        viewModel.overtimeSeconds = 0
        window?.anyKeyDismisses = true
    }

    func updateOvertime(_ seconds: Int) {
        viewModel.overtimeSeconds = seconds
    }

    func dismiss() {
        viewModel.stopVolumeMonitoring()
        showCursor()
        cursorHideTimer?.invalidate()
        cursorHideTimer = nil
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseMonitor = nil
        }
        guard let window = window else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.5
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
            self?.window = nil
            self?.hostingController = nil
        })
    }
}

final class BreakViewModel: ObservableObject {
    @Published var secondsRemaining: Int = 0
    @Published var breakOver: Bool = false
    @Published var breakDurationMinutes: Int = 5
    @Published var overtimeSeconds: Int = 0
    @Published var showVolume: Bool = false
    @Published var systemVolume: Int = 0

    private var volumeTimer: Timer?
    private var listenerBlock: AudioObjectPropertyListenerBlock?

    func startVolumeMonitoring() {
        showVolume = true
        systemVolume = Self.getSystemVolume()

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let deviceID = Self.defaultOutputDevice()
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.systemVolume = Self.getSystemVolume()
            }
        }
        listenerBlock = block
        AudioObjectAddPropertyListenerBlock(deviceID, &address, DispatchQueue.main, block)
    }

    func stopVolumeMonitoring() {
        showVolume = false
        guard let block = listenerBlock else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let deviceID = Self.defaultOutputDevice()
        AudioObjectRemovePropertyListenerBlock(deviceID, &address, DispatchQueue.main, block)
        listenerBlock = nil
    }

    static func defaultOutputDevice() -> AudioDeviceID {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        return deviceID
    }

    static func getSystemVolume() -> Int {
        let deviceID = defaultOutputDevice()
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
        return Int(round(volume * 100))
    }

    var timeString: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return String(format: "%d:%02d", m, s)
    }

    var breakDurationString: String {
        "\(breakDurationMinutes) min completed"
    }

    var overtimeString: String {
        let m = overtimeSeconds / 60
        let s = overtimeSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct BreakCountdownView: View {
    @ObservedObject var viewModel: BreakViewModel
    var onEndBreak: () -> Void
    @State private var endBreakHovered = false
    @State private var continueHovered = false
    @State private var cursorVisible = true
    @State private var hideTimer: Timer?

    private let accentGold = Color(red: 0.769, green: 0.639, blue: 0.353)

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)

            if viewModel.breakOver {
                VStack(spacing: 16) {
                    Text("Break over")
                        .font(.system(size: 72, weight: .ultraLight, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.9))

                    HStack(spacing: 6) {
                        Text(viewModel.breakDurationString)
                            .font(.system(size: 24, weight: .light, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text("+")
                            .font(.system(size: 24, weight: .light, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text(viewModel.overtimeString)
                            .font(.system(size: 24, weight: .light, design: .rounded))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Button(action: onEndBreak) {
                        Text("Continue")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(accentGold.opacity(continueHovered ? 1.0 : 0.6))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(accentGold.opacity(continueHovered ? 0.15 : 0.05))
                            .clipShape(Capsule())
                            .animation(.easeInOut(duration: 0.15), value: continueHovered)
                    }
                    .buttonStyle(.plain)
                    .onHover { continueHovered = $0 }
                    .padding(.top, 16)
                }
            } else {
                VStack(spacing: 32) {
                    Text(viewModel.timeString)
                        .font(.system(size: 72, weight: .ultraLight, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.9))
                        .monospacedDigit()

                    if viewModel.showVolume {
                        HStack(spacing: 6) {
                            Image(systemName: volumeIcon)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Text("\(viewModel.systemVolume)%")
                                .font(.system(size: 13, weight: .light, design: .rounded))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }

                    Button(action: onEndBreak) {
                        Text("End Break")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(accentGold.opacity(endBreakHovered ? 1.0 : 0.6))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(accentGold.opacity(endBreakHovered ? 0.15 : 0.05))
                            .clipShape(Capsule())
                            .animation(.easeInOut(duration: 0.15), value: endBreakHovered)
                    }
                    .buttonStyle(.plain)
                    .onHover { endBreakHovered = $0 }
                    .opacity(cursorVisible ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.5), value: cursorVisible)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { scheduleHide() }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                if !cursorVisible { cursorVisible = true }
                if !endBreakHovered && !continueHovered { scheduleHide() }
            case .ended:
                break
            }
        }
    }

    private var volumeIcon: String {
        let v = viewModel.systemVolume
        if v == 0 { return "speaker.slash" }
        if v < 33 { return "speaker.wave.1" }
        if v < 66 { return "speaker.wave.2" }
        return "speaker.wave.3"
    }

    private func scheduleHide() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            if !endBreakHovered {
                cursorVisible = false
            }
        }
    }
}
#endif
