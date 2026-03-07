# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
bash build.sh    # kills running instance, compiles, bundles .app, codesigns, registers with LaunchServices, launches
```

No Xcode required — builds with `swiftc` directly. The script assembles the `.app` bundle manually (binary, Info.plist, sound resources, icon assets, codesign). New `.swift` files must be added to the `swiftc` invocation in `build.sh`.

Target: macOS 13.0+ (arm64), Swift 5. Signed locally (`codesign --sign -`). Bundle ID: `com.sati.mindfulness`.

## Architecture

Menu bar-only app (`LSUIElement=true`, no dock icon) using `MenuBarExtra` with `.window` style for a popover UI.

**`SatiApp.swift`** — Entry point. `AppDelegate` sets the app icon programmatically on launch. `AppState` owns the two core objects and wires them together. The `MenuBarExtra` renders `SettingsView` as its popover and `BuddhaIcon` as its menu bar image.

**`ReminderManager.swift`** — Core logic. `ObservableObject` that runs a 1-second timer, sends `UNUserNotificationCenter` notifications with rotating mindfulness phrases and a singing bowl sound when the interval elapses. Notifications are temporary — auto-removed from Notification Center after 8 seconds. Handles snooze (timed or VLC-based). Registers notification actions (15m, 30m, More...) and acts as `UNUserNotificationCenterDelegate`. Settings persisted via `UserDefaults`.

**`VLCMonitor.swift`** — Polls `NSWorkspace.shared.runningApplications` every 5s for VLC. When VLC quits and `snoozedForVLC` is set, auto-resumes reminders via Combine subscription.

**`SettingsView.swift`** — Popover UI. Contains reusable hover-aware button components (`HoverButton`, `HoverCircleButton`, `SnoozeChip`) and a custom `VLCConeShape`. Uses semantic SwiftUI colors (`.primary`/`.secondary`) for light/dark mode support.

**`BuddhaIcon.swift`** — Loads a PNG template image from the app bundle (`buddha@2x.png`) for the menu bar icon. Set as template image for automatic menu bar color adaptation. Snoozed state reduces opacity and adds "z" text. Falls back to a circle if image not found.

## Resources

- `Sati/Resources/buddha@2x.png` (44×44) and `buddha.png` (22×22) — Menu bar template icon (black with alpha channel)
- `Sati/Resources/AppIcon.icns` — App icon shown in notifications (warm charcoal background with gold-tinted buddha)
- `Sati/Sounds/bowl.aif` — Singing bowl notification sound

## Icon Cache

macOS aggressively caches app icons. `build.sh` runs `lsregister -f` to force icon updates. If the notification icon still shows stale, change `CFBundleIdentifier` in `build.sh` temporarily, build, approve notifications, then change it back.

## UI Conventions

- Semantic colors only (`.primary`, `.secondary`, `.primary.opacity(...)`) — never hardcoded color values for text/backgrounds
- Gold accent: `Color(red: 0.769, green: 0.639, blue: 0.353)` for interactive elements
- Green status dot: `Color(red: 0.33, green: 0.72, blue: 0.44)` for active state
- All clickable elements use `onHover` with 150ms animated background highlight
- macOS 13 APIs only — use `onChange(of:) { newValue in }` (single-param closure), not the macOS 14+ two-param variant
