#!/bin/bash
# Test script for notify.sh - full e2e with mocked notify-send

SCRIPT_DIR="$(dirname "$0")"
NOTIFY_SCRIPT="$SCRIPT_DIR/notify.sh"

# Create temp dir for marker file and mock binary
TEMP_DIR=$(mktemp -d)
TRANSCRIPT_PATH="$TEMP_DIR/transcript.json"
touch "$TRANSCRIPT_PATH"

# Create mock notify-send that logs calls and simulates -p (print ID)
MOCK_BIN="$TEMP_DIR/bin"
mkdir -p "$MOCK_BIN"
MOCK_NOTIFY_ID=1000
cat > "$MOCK_BIN/notify-send" <<'MOCK'
#!/bin/bash
echo "[notify-send] $*" >&2
# If -p flag present, output an incrementing ID (simulates real behavior)
for arg in "$@"; do
    if [ "$arg" = "-p" ]; then
        # Use a counter file to increment IDs
        COUNTER_FILE="/tmp/mock-notify-counter"
        if [ -f "$COUNTER_FILE" ]; then
            ID=$(cat "$COUNTER_FILE")
        else
            ID=1000
        fi
        echo $((ID + 1)) > "$COUNTER_FILE"
        echo "$ID"
        break
    fi
done
MOCK
chmod +x "$MOCK_BIN/notify-send"
rm -f /tmp/mock-notify-counter

# Prepend mock to PATH
export PATH="$MOCK_BIN:$PATH"

# Simulated session values
SESSION_ID="test-session-abc123"
CWD="/home/user/projects/my-app"

# Override threshold for quick testing
export DELAY_THRESHOLD=1

send_event() {
    local event="$1"
    local extra_fields="${2:-}"

    local json=$(cat <<EOF
{
  "hook_event_name": "$event",
  "transcript_path": "$TRANSCRIPT_PATH",
  "session_id": "$SESSION_ID",
  "cwd": "$CWD"$extra_fields
}
EOF
)
    echo "=== $event ==="
    echo "$json" | "$NOTIFY_SCRIPT" 2>&1
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "ERROR: exit code $exit_code"
    fi
    echo
    return $exit_code
}

echo "Testing notify.sh (mocked notify-send)"
echo "Session: $SESSION_ID"
echo "CWD: $CWD"
echo

# Test 1: Submit, wait, Stop (should notify)
echo "--- Test: Response ready notification ---"
send_event "UserPromptSubmit"
sleep 2
send_event "Stop"

# Test 2: Submit, Stop immediately (should NOT notify)
echo "--- Test: Quick response (no notification expected) ---"
send_event "UserPromptSubmit"
send_event "Stop"

# Test 3: Notification events (after threshold)
echo "--- Test: Notification events ---"
send_event "UserPromptSubmit"
sleep 2
send_event "Notification" ', "notification_type": "permission_prompt"'
send_event "Notification" ', "notification_type": "idle_prompt"'
send_event "Notification" ', "notification_type": "some_other"'

# Cleanup
rm -rf "$TEMP_DIR"

echo "=== All tests complete ==="
