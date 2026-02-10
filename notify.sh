#!/bin/bash
# Claude Code notification helper
# Debounced: only notifies after DEBOUNCE_SECONDS of silence, and only if
# the response took longer than DELAY_THRESHOLD seconds. (Linux, uses notify-send)
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
CWD=$(echo "$INPUT" | jq -r '.cwd')
SESSION_DIR="$(dirname "$TRANSCRIPT_PATH")"
MARKER_FILE="$SESSION_DIR/.prompt-start"
NOTIFY_ID_FILE="$SESSION_DIR/.notify-id"
PENDING_PID_FILE="$SESSION_DIR/.notify-pending-pid"

DELAY_THRESHOLD="${DELAY_THRESHOLD:-15}"  # Only notify if response took >N seconds
DEBOUNCE_SECONDS="${DEBOUNCE_SECONDS:-15}"  # Wait for silence before sending

# Returns 0 if threshold passed, 1 otherwise. Sets $elapsed.
check_threshold() {
    [ -f "$MARKER_FILE" ] || return 1
    start_time=$(stat -c %Y "$MARKER_FILE")
    now=$(date +%s)
    elapsed=$((now - start_time))
    [ "$elapsed" -gt "$DELAY_THRESHOLD" ]
}

# Get short project name from cwd (last component of path)
project_name() {
    basename "$CWD"
}

# Send notification, replacing previous if exists. Stores new ID for next time.
send_notify() {
    local urgency="$1" title="$2" body="$3"
    local args=(-p)
    [ -f "$NOTIFY_ID_FILE" ] && args+=(-r "$(cat "$NOTIFY_ID_FILE")")
    [ -n "$urgency" ] && args+=(-u "$urgency")
    notify-send "${args[@]}" "$title" "$body" > "$NOTIFY_ID_FILE"
}

# Cancel any pending debounced notification
cancel_pending() {
    if [ -f "$PENDING_PID_FILE" ]; then
        kill "$(cat "$PENDING_PID_FILE")" 2>/dev/null || true
        rm -f "$PENDING_PID_FILE"
    fi
}

# Schedule a notification after DEBOUNCE_SECONDS of silence
schedule_notify() {
    local urgency="$1" title="$2" body="$3"
    cancel_pending
    (
        sleep "$DEBOUNCE_SECONDS"
        send_notify "$urgency" "$title" "$body"
        rm -f "$PENDING_PID_FILE"
    ) &
    disown $!
    echo $! > "$PENDING_PID_FILE"
}

case "$EVENT" in
    UserPromptSubmit)
        mkdir -p "$SESSION_DIR"
        touch "$MARKER_FILE"
        cancel_pending
        ;;

    Stop)
        if check_threshold; then
            schedule_notify "" "Claude [$(project_name)]" "Response ready (${elapsed}s)"
        fi
        rm -f "$MARKER_FILE"
        ;;

    Notification)
        if check_threshold; then
            notify_type=$(echo "$INPUT" | jq -r '.notification_type // "unknown"')
            case "$notify_type" in
                permission_prompt)
                    schedule_notify "critical" "Claude [$(project_name)]" "Permission required"
                    ;;
                idle_prompt)
                    schedule_notify "" "Claude [$(project_name)]" "Waiting for input"
                    ;;
                *)
                    schedule_notify "" "Claude [$(project_name)]" "Notification: $notify_type"
                    ;;
            esac
        fi
        ;;
esac

exit 0
