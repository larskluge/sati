#!/bin/bash
# Pull and display sati.jsonl from all devices
# Usage: bash logs.sh [ios|watch|mac|all]

set -e
LOGDIR="/tmp/sati-logs"
mkdir -p "$LOGDIR"

IPHONE="Phone25"
WATCH="Lars's Apple Watch"
IOS_BUNDLE="com.sati.Sati"
WATCH_BUNDLE="com.sati.Sati.watchkitapp"

pull_ios() {
    echo "=== iOS ($IPHONE) ==="
    xcrun devicectl device copy from \
        --device "$IPHONE" \
        --domain-type appDataContainer \
        --domain-identifier "$IOS_BUNDLE" \
        --source Documents/sati.jsonl \
        --destination "$LOGDIR/ios.jsonl" 2>/dev/null && \
    cat "$LOGDIR/ios.jsonl" || echo "(no log file yet)"
}

pull_watch() {
    echo "=== watchOS ($WATCH) ==="
    xcrun devicectl device copy from \
        --device "$WATCH" \
        --domain-type appDataContainer \
        --domain-identifier "$WATCH_BUNDLE" \
        --source Documents/sati.jsonl \
        --destination "$LOGDIR/watch.jsonl" 2>/dev/null && \
    cat "$LOGDIR/watch.jsonl" || echo "(no log file yet)"
}

pull_mac() {
    echo "=== macOS ==="
    MAC_LOG="$HOME/Library/Logs/Sati/sati.jsonl"
    if [ -f "$MAC_LOG" ]; then
        cat "$MAC_LOG"
    else
        echo "(no log file yet at $MAC_LOG)"
    fi
}

case "${1:-all}" in
    ios)   pull_ios ;;
    watch) pull_watch ;;
    mac)   pull_mac ;;
    all)   pull_mac; echo; pull_ios; echo; pull_watch ;;
    *)     echo "Usage: bash logs.sh [ios|watch|mac|all]" ;;
esac
