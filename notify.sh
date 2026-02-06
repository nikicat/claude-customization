#!/bin/bash
# Claude Code notification helper
# Notifies when responses are ready or attention is needed (Linux, uses notify-send)
#
# Install: Copy to ~/.claude/hooks/notify.sh and chmod +x
# Configure in ~/.claude/settings.json (see README.md)
#
# Dependencies: jq, notify-send
# For macOS: replace notify-send with osascript

set -e

INPUT=$(cat)
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path')
MARKER_FILE="$(dirname "$TRANSCRIPT_PATH")/.prompt-start"

DELAY_THRESHOLD=15  # Only notify if response took >15 seconds

# Returns 0 if threshold passed, 1 otherwise. Sets $elapsed.
check_threshold() {
    [ -f "$MARKER_FILE" ] || return 1
    start_time=$(stat -c %Y "$MARKER_FILE")
    now=$(date +%s)
    elapsed=$((now - start_time))
    [ "$elapsed" -gt "$DELAY_THRESHOLD" ]
}

case "$EVENT" in
    UserPromptSubmit)
        touch "$MARKER_FILE"
        ;;

    Stop)
        if check_threshold; then
            notify-send "Claude" "Response ready (${elapsed}s)"
        fi
        rm -f "$MARKER_FILE"
        ;;

    Notification)
        if check_threshold; then
            notify_type=$(echo "$INPUT" | jq -r '.notification_type // "unknown"')
            case "$notify_type" in
                permission_prompt)
                    notify-send -u critical "Claude" "Permission required"
                    ;;
                idle_prompt)
                    notify-send "Claude" "Waiting for input"
                    ;;
                *)
                    notify-send "Claude" "Notification: $notify_type"
                    ;;
            esac
        fi
        ;;
esac

exit 0
