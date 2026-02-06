# Claude Code Customization Guide

How to run multiple Claude Code accounts on a single machine and set up desktop notifications.

## Problem: Multiple OAuth Accounts

You may need separate Claude accounts for work vs personal use, or to isolate billing/usage. Claude Code stores all state in a single config directory (`~/.claude` by default), including OAuth credentials.

## Solution: Split Config Directories

Claude Code respects the `CLAUDE_CONFIG_DIR` environment variable. Create separate directories and use shell aliases:

```bash
# Create separate config directories
mkdir -p ~/.claude-personal ~/.claude-work

# Shell aliases (add to .bashrc, .zshrc, or config.fish)
alias claude-work="CLAUDE_CONFIG_DIR=$HOME/.claude-work claude"
alias claude-personal="CLAUDE_CONFIG_DIR=$HOME/.claude-personal claude"
```

Each directory gets its own:
- `.credentials.json` — OAuth tokens (separate accounts)
- `history.jsonl` — conversation history
- `projects/` — per-project settings

### Sharing Configuration Across Accounts

To share settings/plugins while keeping accounts separate, use symlinks:

```bash
# Keep shared config in ~/.claude, symlink from each account
ln -s ~/.claude/CLAUDE.md ~/.claude-personal/CLAUDE.md
ln -s ~/.claude/CLAUDE.md ~/.claude-work/CLAUDE.md
ln -s ~/.claude/settings.json ~/.claude-personal/settings.json
ln -s ~/.claude/settings.json ~/.claude-work/settings.json
ln -s ~/.claude/plugins ~/.claude-personal/plugins
ln -s ~/.claude/plugins ~/.claude-work/plugins
```

## Problem: Missing Long-Running Task Notifications

When Claude takes a while to respond, you switch to another window and miss when it's ready. Or Claude needs permission approval and you don't notice.

## Solution: Notification Hooks

1. Install the hook script (choose one):
   - **Copy:** `cp notify.sh ~/.claude/hooks/notify.sh`
   - **Symlink:** `ln -s "$(pwd)/notify.sh" ~/.claude/hooks/notify.sh` (easier updates)
2. Make executable: `chmod +x ~/.claude/hooks/notify.sh`
3. Configure hooks in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify.sh" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify.sh" }] }
    ],
    "Notification": [
      { "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify.sh" }] }
    ]
  }
}
```

**Dependencies:** `jq`, `notify-send` (Linux). For macOS, replace `notify-send` with `osascript`.

## Hook Events Reference

| Event | When Triggered |
|-------|---------------|
| `UserPromptSubmit` | User sends a prompt |
| `Stop` | Claude finishes responding |
| `Notification` | Claude needs attention (permission prompts, idle, etc.) |

The script uses a marker file to track elapsed time, only notifying when responses take longer than 15 seconds (configurable via `DELAY_THRESHOLD`).
