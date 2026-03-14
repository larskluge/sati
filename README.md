# Sati

A mindfulness reminder app for Apple platforms. Sends periodic notifications with rotating phrases and a singing bowl sound.

![macOS 15+](https://img.shields.io/badge/macOS-15%2B-blue) ![iOS 18+](https://img.shields.io/badge/iOS-18%2B-blue) ![watchOS 11+](https://img.shields.io/badge/watchOS-11%2B-blue)

## Features

- Periodic notifications with rotating mindfulness phrases and singing bowl sound
- Configurable reminder interval (default 5 minutes)
- Topics of investigation — rotating focus areas on a half-day schedule
- Notifications auto-dismiss from Notification Center after 8 seconds
- Snooze from notification actions (15m, 30m) or from the popover (15m, 30m, 45m, 1h)
- Auto-snooze while VLC is playing, auto-resume when it quits (macOS)
- Launch at Login toggle (macOS)
- Menu bar-only on macOS — no dock icon, just a buddha icon in the menu bar
- Snoozed state shown with dimmed icon and "z" indicator
- Supports light and dark mode
- iOS app with topic management, interval editing, and notifications toggle
- macOS↔iOS sync via MultipeerConnectivity on local network (auto-discover, last-write-wins)
- watchOS companion app with haptic reminders (success pattern) and topic display
- iPhone→Watch sync via WatchConnectivity (topics, active topic, interval)

## Build

Requires Xcode. macOS 15+ / iOS 18+ / watchOS 11+.

```bash
bash build.sh
```

This builds with `xcodebuild` and registers with LaunchServices. Or open `Sati/Sati.xcodeproj` in Xcode directly. For iOS and watchOS, build and run from Xcode to a connected device.

## Install

Build from Xcode or copy the built `Sati.app` to `/Applications`. Right-click → Open to bypass Gatekeeper on first launch.

## Usage

Click the buddha icon in the menu bar to open the popover:

- **Status** — shows Active (green dot) or Snoozed state with time remaining and resume button
- **Topic** — current topic of investigation displayed inline when active
- **Snooze** — quick snooze chips (15m, 30m, 45m, 1h) plus VLC auto-snooze when VLC is running
- **Every __ min** — adjust the reminder interval with +/- buttons
- **Settings** — gear icon opens a settings window with topics management, sound toggle, and launch at login

Notifications include action buttons for quick snooze (15m, 30m, More...) without opening the popover.

## Architecture

```
Sati/Sati/
  SatiApp.swift          # Cross-platform entry point, AppDelegate, AppState, MenuBarExtra
  ReminderManager.swift  # Timer, notifications, snooze logic (platform-agnostic core)
  TopicManager.swift     # Rotating topics on half-day schedule (platform-agnostic)
  VLCMonitor.swift       # Polls for VLC process, auto-resume (macOS-only)
  SettingsView.swift     # Popover UI with hover-aware components (macOS-only)
  SettingsWindow.swift   # Standalone settings window (macOS-only)
  BuddhaIcon.swift       # Menu bar template image with snooze state (macOS-only)
  ContentView.swift      # Topic management, interval, notifications toggle (iOS)
  TopicRotation.swift    # Half-day rotation formula (shared logic)
  SyncPayload.swift      # Peer sync payload, hashing, conflict resolution
  WatchContextCoder.swift # Watch context encode/decode
  PeerSyncManager.swift  # MultipeerConnectivity sync (macOS + iOS)
  WatchConnectivitySender.swift  # iPhone→Watch sync (iOS-only)
  SatiLog.swift          # Dual file+os.Logger logging
  Info.plist             # Bonjour + local network permissions
  Sati.entitlements      # Sandbox + network entitlements (macOS)
  Resources/
    buddha@2x.png        # Menu bar icon (44x44 template)
    buddha.png           # Menu bar icon (22x22 template)
    AppIcon.icns         # Notification icon
  Sounds/
    bowl.aif             # Singing bowl notification sound

Sati/SatiWatch/
  SatiWatchApp.swift     # Entry point, owns watch managers
  WatchReminderManager.swift  # Haptic reminders via WKExtendedRuntimeSession
  WatchTopicStore.swift  # Local topic storage with half-day rotation
  WatchConnectivityReceiver.swift  # Receives state from iPhone
  WatchMainView.swift    # Main UI: status, topic, snooze
  WatchSettingsView.swift  # Interval stepper, haptic picker, sync status
  WatchDebugView.swift   # WCSession debug info
  TopicRotation.swift    # Shared rotation formula (copy)
  WatchContextCoder.swift # Shared context codec (copy)
  SatiLog.swift          # Dual file+os.Logger logging

Sati/SatiTests/          # Unit tests (macOS + iOS)
Sati/SatiWatchTests/     # Unit tests (watchOS)
```

## Testing

```bash
# macOS
xcodebuild test -project Sati/Sati.xcodeproj -scheme Sati -destination 'platform=macOS' -only-testing:SatiTests

# iOS (simulator)
xcodebuild test -project Sati/Sati.xcodeproj -scheme Sati -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SatiTests

# watchOS (simulator)
xcodebuild test -project Sati/Sati.xcodeproj -scheme SatiWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' -only-testing:SatiWatchTests
```

Tests cover the extracted sync logic: `TopicRotation`, `SyncPayload`, `WatchContextCoder`, `TopicManager`, and `WatchTopicStore`.
