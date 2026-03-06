# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
bash build.sh    # kills running instance, compiles, bundles .app, codesigns, launches
```

No Xcode required — builds with `swiftc` directly. The script assembles the `.app` bundle manually (binary, Info.plist, sound resources, codesign). New `.swift` files must be added to the `swiftc` invocation in `build.sh`.

Target: macOS 13.0+ (arm64), Swift 5. Signed locally (`codesign --sign -`).

## Architecture

Menu bar-only app (`LSUIElement=true`, no dock icon) using `MenuBarExtra` with `.window` style for a popover UI.

**`SatiApp.swift`** — Entry point. `AppState` owns the two core objects and wires them together. The `MenuBarExtra` renders `SettingsView` as its popover and `BuddhaIcon` as its menu bar image.

**`ReminderManager.swift`** — Core logic. `ObservableObject` that runs a 1-second timer, sends `UNUserNotificationCenter` notifications with rotating mindfulness phrases and a singing bowl sound when the interval elapses. Handles snooze (timed or VLC-based). Registers notification actions (15m, 30m, More...) and acts as `UNUserNotificationCenterDelegate`. Settings persisted via `UserDefaults`.

**`VLCMonitor.swift`** — Polls `NSWorkspace.shared.runningApplications` every 5s for VLC. When VLC quits and `snoozedForVLC` is set, auto-resumes reminders via Combine subscription.

**`SettingsView.swift`** — Popover UI. Contains reusable hover-aware button components (`HoverButton`, `HoverCircleButton`, `SnoozeChip`) and a custom `VLCConeShape`. Uses semantic SwiftUI colors (`.primary`/`.secondary`) for light/dark mode support.

**`BuddhaIcon.swift`** — Draws the menu bar icon programmatically via `NSBezierPath` (seated meditation figure in lotus position). Returns `NSImage` set as template image for automatic menu bar color adaptation. Snoozed state reduces opacity and adds "z" text.

## UI Conventions

- Semantic colors only (`.primary`, `.secondary`, `.primary.opacity(...)`) — never hardcoded color values for text/backgrounds
- Gold accent: `Color(red: 0.769, green: 0.639, blue: 0.353)` for interactive elements
- Green status dot: `Color(red: 0.33, green: 0.72, blue: 0.44)` for active state
- All clickable elements use `onHover` with 150ms animated background highlight
- macOS 13 APIs only — use `onChange(of:) { newValue in }` (single-param closure), not the macOS 14+ two-param variant
