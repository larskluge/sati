# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
bash build.sh    # kills running instance, builds with xcodebuild, registers with LaunchServices, launches
```

Xcode project at `Sati/Sati.xcodeproj`. Multi-platform (macOS + iOS) with macOS as the primary target. Uses `PBXFileSystemSynchronizedRootGroup` — new files added to `Sati/Sati/` are automatically included in the build.

Target: macOS 15.0+ / iOS 18.0+ (arm64), Swift 5. Bundle ID: `com.sati.Sati`.

Concurrency: project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES`. All types are implicitly `@MainActor`. Protocol delegate callbacks (e.g. `UNUserNotificationCenterDelegate`) need `nonisolated` markers. `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` means transitive imports don't count — always import modules explicitly (e.g. `import Combine` for `@Published`).

## Architecture

Menu bar-only app on macOS (`LSUIElement=true`, no dock icon) using `MenuBarExtra` with `.window` style for a popover UI. iOS shows a placeholder `ContentView`.

macOS-specific files are wrapped in `#if os(macOS)`. Platform-agnostic core logic (`ReminderManager`, `TopicManager`) can be shared with future targets (watchOS).

**`SatiApp.swift`** — Cross-platform entry point. `AppDelegate` sets the app icon on macOS. `AppState` owns the core objects and wires them together. `MenuBarExtra` renders `SettingsView` as its popover and `BuddhaIcon` as its menu bar image on macOS; `ContentView` on iOS.

**`ReminderManager.swift`** — Core logic (platform-agnostic except `connectVLCMonitor`). `ObservableObject` that runs a 1-second timer, sends `UNUserNotificationCenter` notifications with rotating mindfulness phrases and a singing bowl sound when the interval elapses. Notifications are temporary — auto-removed from Notification Center after 8 seconds. Handles snooze (timed or VLC-based). Registers notification actions (15m, 30m, More...) and acts as `UNUserNotificationCenterDelegate`. Settings persisted via `UserDefaults`.

**`TopicManager.swift`** — Platform-agnostic. Manages rotating "topics of investigation" on a half-day schedule. Persists topics and active offset to `UserDefaults`.

**`VLCMonitor.swift`** — macOS-only (`#if os(macOS)`). Polls `NSWorkspace.shared.runningApplications` every 5s for VLC. When VLC quits and `snoozedForVLC` is set, auto-resumes reminders via Combine subscription.

**`SettingsView.swift`** — macOS-only (`#if os(macOS)`). Popover UI. Contains reusable hover-aware button components (`HoverButton`, `HoverCircleButton`, `SnoozeChip`) and a custom `VLCConeShape`. Uses semantic SwiftUI colors (`.primary`/`.secondary`) for light/dark mode support.

**`SettingsWindow.swift`** — macOS-only (`#if os(macOS)`). Standalone settings window with topics management, notification sound toggle, and launch-at-login toggle.

**`BuddhaIcon.swift`** — macOS-only (`#if os(macOS)`). Loads a PNG template image from the app bundle (`buddha@2x.png`) for the menu bar icon. Set as template image for automatic menu bar color adaptation. Snoozed state reduces opacity and adds "z" text. Falls back to a circle if image not found.

**`ContentView.swift`** — iOS placeholder UI.

## Resources

All resources live under `Sati/Sati/` and are auto-included via file system sync:

- `Resources/buddha@2x.png` (44×44) and `buddha.png` (22×22) — Menu bar template icon (black with alpha channel)
- `Resources/AppIcon.icns` — App icon shown in notifications (warm charcoal background with gold-tinted buddha)
- `Sounds/bowl.aif` — Singing bowl notification sound

## Icon Cache

macOS aggressively caches app icons. `build.sh` runs `lsregister -f` to force icon updates. If the notification icon still shows stale, change `CFBundleIdentifier` temporarily, build, approve notifications, then change it back.

## UI Conventions

- Semantic colors only (`.primary`, `.secondary`, `.primary.opacity(...)`) — never hardcoded color values for text/backgrounds
- Gold accent: `Color(red: 0.769, green: 0.639, blue: 0.353)` for interactive elements
- Green status dot: `Color(red: 0.33, green: 0.72, blue: 0.44)` for active state
- All clickable elements use `onHover` with 150ms animated background highlight
- macOS 15+ APIs — use two-param `onChange(of:) { oldValue, newValue in }` syntax
