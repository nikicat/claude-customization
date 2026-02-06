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
CWD=$(echo "$INPUT" | jq -r '.cwd')
SESSION_DIR="$(dirname "$TRANSCRIPT_PATH")"
MARKER_FILE="$SESSION_DIR/.prompt-start"
NOTIFY_ID_FILE="$SESSION_DIR/.notify-id"

DELAY_THRESHOLD="${DELAY_THRESHOLD:-15}"  # Only notify if response took >N seconds

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
    local urgency="$1"
    local title="$2"
    local body="$3"
    local args=(-p)

    # Replace previous notification if we have its ID
    if [ -f "$NOTIFY_ID_FILE" ]; then
        args+=(-r "$(cat "$NOTIFY_ID_FILE")")
    fi

    [ -n "$urgency" ] && args+=(-u "$urgency")

    # Send and capture new notification ID
    notify-send "${args[@]}" "$title" "$body" > "$NOTIFY_ID_FILE"
}

case "$EVENT" in
    UserPromptSubmit)
        touch "$MARKER_FILE"
        ;;

    Stop)
        if check_threshold; then
            send_notify "" "Claude [$(project_name)]" "Response ready (${elapsed}s)"
        fi
        rm -f "$MARKER_FILE"
        ;;

    Notification)
        if check_threshold; then
            notify_type=$(echo "$INPUT" | jq -r '.notification_type // "unknown"')
            case "$notify_type" in
                permission_prompt)
                    send_notify "critical" "Claude [$(project_name)]" "Permission required"
                    ;;
                idle_prompt)
                    send_notify "" "Claude [$(project_name)]" "Waiting for input"
                    ;;
                *)
                    send_notify "" "Claude [$(project_name)]" "Notification: $notify_type"
                    ;;
            esac
        fi
        ;;
esac

exit 0
