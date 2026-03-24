# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
make             # builds with xcodebuild, registers with LaunchServices
make install     # builds and copies Sati.app to /Applications
```

Xcode project at `Sati/Sati.xcodeproj`. Multi-platform (macOS + iOS + watchOS) with macOS as the primary target. Uses `PBXFileSystemSynchronizedRootGroup` — new files added to `Sati/Sati/` or `Sati/SatiWatch/` are automatically included in their respective targets.

Targets: macOS 15.0+ / iOS 18.0+ (arm64), Swift 5. Bundle ID: `com.sati.Sati`. watchOS 11.0+ target `SatiWatch` with bundle ID `com.sati.Sati.watchkitapp`. Test targets: `SatiTests` (macOS/iOS, hosted in Sati.app) and `SatiWatchTests` (watchOS, hosted in SatiWatch.app).

Concurrency: project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES`. All types are implicitly `@MainActor`. Protocol delegate callbacks (e.g. `UNUserNotificationCenterDelegate`) need `nonisolated` markers. `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` means transitive imports don't count — always import modules explicitly (e.g. `import Combine` for `@Published`).

## Architecture

Menu bar-only app on macOS (`LSUIElement=true`, no dock icon) using `MenuBarExtra` with `.window` style for a popover UI. iOS shows topic management + settings. macOS↔iOS sync via MultipeerConnectivity on local network.

macOS-specific files are wrapped in `#if os(macOS)`. iOS-specific code uses `#if os(iOS)`. The watchOS target (`SatiWatch/`) is a separate set of files — not shared code.

**`SatiApp.swift`** — Cross-platform entry point. `AppState` owns the core objects and wires them together. On iOS, `PeerSyncManager` and `WatchConnectivitySender` are deferred to after first frame via `startBackgroundServices()`. `MenuBarExtra` renders `SettingsView` as its popover and `BuddhaIcon` as its menu bar image on macOS; `ContentView` on iOS.

**`ReminderManager.swift`** — Core logic (platform-agnostic except `connectVLCMonitor`). `ObservableObject` that runs a 1-second timer, sends `UNUserNotificationCenter` notifications with rotating mindfulness phrases and a singing bowl sound when the interval elapses. Notifications are temporary — auto-removed from Notification Center after 8 seconds. Handles snooze (timed or VLC-based). Registers notification actions (15m, 30m, More...) and acts as `UNUserNotificationCenterDelegate`. `isActive` defaults to `true` on macOS, `false` on iOS. Settings persisted via `UserDefaults`.

**`TopicRotation.swift`** — Pure struct with static methods for half-day rotation math. `halfDaySlot(for:calendar:)` computes the current slot, `activeIndex(slot:offset:count:)` maps to a topic index, `offset(forDesiredIndex:slot:count:)` computes the offset to pin a desired topic. Shared by `TopicManager` and `WatchTopicStore`. Copied to `SatiWatch/` for the watchOS target.

**`SyncPayload.swift`** — Value type for peer sync data (topics, offset, interval, updatedAt). Handles dictionary serialization (`toDictionary`/`fromDictionary`), content hashing (excludes timestamp), and last-write-wins conflict resolution (`shouldReplace`). Used by `PeerSyncManager`.

**`WatchContextCoder.swift`** — Encodes/decodes `WatchContext` for WatchConnectivity `applicationContext`. Topics encoded as JSON `Data` on send; decoder handles both `Data` and `[String]` array formats. Copied to `SatiWatch/` for the watchOS target.

**`TopicManager.swift`** — Platform-agnostic. Manages rotating "topics of investigation" using `TopicRotation`. Accepts `UserDefaults` via init for test isolation. Persists topics and active offset to `UserDefaults`. `offset` is `@Published` so sync managers observe active topic changes.

**`VLCMonitor.swift`** — macOS-only (`#if os(macOS)`). Polls `NSWorkspace.shared.runningApplications` every 5s for VLC. When VLC quits and `snoozedForVLC` is set, auto-resumes reminders via Combine subscription.

**`SettingsView.swift`** — macOS-only (`#if os(macOS)`). Popover UI. Contains reusable hover-aware button components (`HoverButton`, `HoverCircleButton`, `SnoozeChip`) and a custom `VLCConeShape`. Uses semantic SwiftUI colors (`.primary`/`.secondary`) for light/dark mode support.

**`SettingsWindow.swift`** — macOS-only (`#if os(macOS)`). Standalone settings window with topics management, notification sound toggle, launch-at-login toggle, and peer sync status.

**`BuddhaIcon.swift`** — macOS-only (`#if os(macOS)`). Loads `MenuBarIcon` from the asset catalog for the menu bar icon. Set as template image for automatic menu bar color adaptation. Snoozed state reduces opacity and adds "z" text. Falls back to a circle if image not found.

**`ContentView.swift`** — iOS-only (`#if os(iOS)`). Takes `AppState`, `TopicManager`, and `ReminderManager` as `@ObservedObject`. Topic management (view, reorder, activate, add/remove), interval stepper, notifications toggle (off by default), and peer sync status. Triggers `appState.startBackgroundServices()` via `.task{}`.

**`PeerSyncManager.swift`** — macOS + iOS (`#if os(macOS) || os(iOS)`). MultipeerConnectivity-based sync over local network. Uses Bonjour service `_sati-sync._tcp`. Auto-discovers peers, auto-accepts connections. Broadcasts topics/offset/interval on local change (debounced 0.5s). Observes `$topics`, `$offset`, and `$intervalMinutes`. Uses `SyncPayload` for serialization and last-write-wins conflict resolution. Tracks `peerConnected`, `connectedPeerName`, `lastSyncDate`.

**`WatchConnectivitySender.swift`** — iOS-only (`#if os(iOS)`). Observes `TopicManager` (`$topics`, `$offset`) and `ReminderManager` (`$intervalMinutes`) via Combine, sends `updateApplicationContext` to paired Apple Watch using `WatchContextCoder`. Debounced 0.5s. Tracks `isPaired`, `isWatchAppInstalled`, `lastSyncDate`.

**`SyncFormatting.swift`** — Shared utility enum for relative-time sync status strings (e.g. "Synced 15s ago"). Uses `RelativeDateTimeFormatter` with `.abbreviated` style. Copied to `SatiWatch/` for the watchOS target.

**`SatiLog.swift`** — Cross-platform logging. Writes to both `os.Logger` and a 256KB ring-buffer file at `Documents/sati.log`. Use `SatiLog.info("Category", "message")`. Log files can be pulled from devices via `logs.sh`.

### watchOS Target (`Sati/SatiWatch/`)

No system notifications on watchOS. Uses `WKExtendedRuntimeSession` (mindfulness type) for background haptic vibration + topic display.

**`SatiWatchApp.swift`** — Entry point. Creates `WatchReminderManager`, `WatchTopicStore`, and `WatchConnectivityReceiver`. Connectivity receiver uses no-arg init with deferred manager wiring via `setManagers()` and activation in `.task{}`.

**`WatchReminderManager.swift`** — Core watch logic. Runs `WKExtendedRuntimeSession(.mindfulness)` for background execution. 1-second timer fires haptic (`WKInterfaceDevice.current().play(.success)`) at interval. Additive snooze (+15m per tap). Auto-restarts session on expiry.

**`WatchTopicStore.swift`** — Local topic storage using `TopicRotation` for half-day rotation. Updated by connectivity receiver.

**`WatchConnectivityReceiver.swift`** — `WCSessionDelegate` on watch side. No-arg init with `setManagers(reminderManager:topicStore:)` for deferred wiring. Receives `applicationContext` from iPhone using `WatchContextCoder`. Supports `requestSync()` for manual sync requests.

**`WatchMainView.swift`** — Main UI: status dot, topic in gold `「」` brackets, snooze button with additive time, gear → settings.

**`WatchSettingsView.swift`** — Interval stepper, resume button, haptic type picker, sync status with iPhone.

**`WatchDebugView.swift`** — Debug view showing WCSession state, connectivity status, and received context.

## Testing

```bash
# macOS
xcodebuild test -project Sati/Sati.xcodeproj -scheme Sati -destination 'platform=macOS' -only-testing:SatiTests

# iOS (simulator)
xcodebuild test -project Sati/Sati.xcodeproj -scheme Sati -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SatiTests

# watchOS (simulator)
xcodebuild test -project Sati/Sati.xcodeproj -scheme SatiWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' -only-testing:SatiWatchTests
```

**`SatiTests`** (macOS/iOS, hosted in Sati.app) — `TopicRotationTests`, `SyncPayloadTests`, `WatchContextCoderTests`, `TopicManagerTests`. **`SatiWatchTests`** (watchOS, hosted in SatiWatch.app) — `WatchTopicStoreTests`, `WatchTopicRotationTests`, `WatchContextCoderWatchTests`.

Test targets use the same Swift concurrency settings as production (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`). `TopicManager` tests require `@MainActor` annotation and must keep instances alive via a class property to avoid a Swift runtime crash in `@MainActor` ObservableObject deinit during test teardown. `TopicManager` accepts `UserDefaults` via init parameter for test isolation.

## Resources

All resources live under `Sati/Sati/` and are auto-included via file system sync:

- `Assets.xcassets/AppIcon.appiconset` — App icon (1024×1024, used for all platforms)
- `Assets.xcassets/MenuBarIcon.imageset` — Menu bar template icon (22×22 @1x, 44×44 @2x)
- `Sounds/bowl.aif` — Singing bowl notification sound

## Icon Cache

macOS aggressively caches app icons. `make build` runs `lsregister -f` to force icon updates. If the notification icon still shows stale, change `CFBundleIdentifier` temporarily, build, approve notifications, then change it back.

## UI Conventions

- Semantic colors only (`.primary`, `.secondary`, `.primary.opacity(...)`) — never hardcoded color values for text/backgrounds
- Gold accent: `Color(red: 0.769, green: 0.639, blue: 0.353)` for interactive elements
- Green status dot: `Color(red: 0.33, green: 0.72, blue: 0.44)` for active state
- All clickable elements use `onHover` with 150ms animated background highlight
- macOS 15+ APIs — use two-param `onChange(of:) { oldValue, newValue in }` syntax

## Logging

All platforms use `SatiLog` which writes to both `os.Logger` (subsystem `com.sati.Sati`) and a file at `Documents/sati.log` (256KB ring buffer). Usage: `SatiLog.info("Category", "message")`.

```bash
bash logs.sh          # pull and display logs from all platforms
bash logs.sh ios      # just iPhone
bash logs.sh watch    # just Apple Watch
bash logs.sh mac      # just macOS
```

Requires devices connected via USB/WiFi. Uses `xcrun devicectl device copy from` for iOS/watchOS.
