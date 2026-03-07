# Sati

A macOS menu bar app that sends periodic mindfulness reminders with a singing bowl sound.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)

## Features

- Periodic notifications with rotating mindfulness phrases and singing bowl sound
- Configurable reminder interval (default 5 minutes)
- Notifications auto-dismiss from Notification Center after 8 seconds
- Snooze from notification actions (15m, 30m) or from the popover (15m, 30m, 1h, 2h)
- Auto-snooze while VLC is playing, auto-resume when it quits
- Launch at Login toggle
- Menu bar-only — no dock icon, just a buddha icon in the menu bar
- Snoozed state shown with dimmed icon and "z" indicator
- Supports light and dark mode

## Build

Requires macOS 13+ (arm64) with Swift toolchain (Xcode Command Line Tools). No Xcode project or Apple Developer account needed.

```bash
bash build.sh
```

This kills any running instance, compiles with `swiftc`, assembles the `.app` bundle with resources, codesigns locally, registers with LaunchServices, and launches `build/Sati.app`.

## Install

Copy `build/Sati.app` to `/Applications`. Right-click → Open to bypass Gatekeeper on first launch.

## Usage

Click the buddha icon in the menu bar to open the popover:

- **Status** — shows Active (green dot) or Snoozed state with time remaining and resume button
- **Snooze** — quick snooze chips (15m, 30m, 1h, 2h) plus VLC auto-snooze
- **Every __ min** — adjust the reminder interval with +/- buttons
- **Launch at Login** — toggle auto-start

Notifications include action buttons for quick snooze (15m, 30m, More...) without opening the popover.

## Architecture

```
Sati/
  SatiApp.swift          # Entry point, AppDelegate, AppState, MenuBarExtra
  ReminderManager.swift  # Timer, notifications, snooze logic, UNUserNotificationCenterDelegate
  VLCMonitor.swift       # Polls for VLC process, auto-resume via Combine
  SettingsView.swift     # Popover UI with hover-aware button components
  BuddhaIcon.swift       # Menu bar template image with snooze state
  Resources/
    buddha@2x.png        # Menu bar icon (44x44 template)
    buddha.png           # Menu bar icon (22x22 template)
    AppIcon.icns         # Notification icon
  Sounds/
    bowl.aif             # Singing bowl notification sound
```
