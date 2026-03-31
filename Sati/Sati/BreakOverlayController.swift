#if os(macOS)
import SwiftUI
import AppKit
import Combine

private class KeyableWindow: NSWindow {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
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

    func show(seconds: Int, onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        viewModel.secondsRemaining = seconds

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

    func dismiss() {
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

    var timeString: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct BreakCountdownView: View {
    @ObservedObject var viewModel: BreakViewModel
    var onEndBreak: () -> Void
    @State private var endBreakHovered = false
    @State private var cursorVisible = true
    @State private var hideTimer: Timer?

    private let accentGold = Color(red: 0.769, green: 0.639, blue: 0.353)

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)

            VStack(spacing: 32) {
                Text(viewModel.timeString)
                    .font(.system(size: 72, weight: .ultraLight, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.9))
                    .monospacedDigit()

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
        .ignoresSafeArea()
        .onAppear { scheduleHide() }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                if !cursorVisible { cursorVisible = true }
                if !endBreakHovered { scheduleHide() }
            case .ended:
                break
            }
        }
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
