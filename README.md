# Sati

A macOS menu bar app that sends mindfulness reminder notifications at a configurable interval.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)

## Features

- Periodic mindfulness notifications with rotating phrases and singing bowl sound
- Configurable interval (default 5 minutes)
- Snooze from notifications (15m, 30m) or from the popover (15m, 30m, 1h, 2h)
- Auto-snooze while VLC is playing, auto-resume when it closes
- Launch at Login toggle
- No dock icon — lives entirely in the menu bar
- Supports light and dark mode

## Build

Requires macOS 13+ with Swift toolchain (Xcode Command Line Tools).

```bash
bash build.sh
```

This compiles, bundles, codesigns locally, and launches `build/Sati.app`.

No Xcode.app or Apple Developer account needed.

## Install

Copy `build/Sati.app` to `/Applications`. Right-click → Open to bypass Gatekeeper on first launch.

## Usage

Click the menu bar icon to open the popover:

- **Status** — shows Active or Snoozed state with resume option
- **Snooze** — quick snooze buttons (15m, 30m, 1h, 2h, or while VLC plays)
- **Every __ min** — set the reminder interval
- **Launch at Login** — toggle auto-start

Notifications include action buttons for quick snooze without opening the popover.
