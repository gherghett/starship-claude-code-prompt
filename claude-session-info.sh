#!/usr/bin/env bash
# Claude Code session info for Starship prompt
# Shows: last modified (smart format), message count, active indicator

CLAUDE_DIR="$HOME/.claude"
SESSIONS_DIR="$CLAUDE_DIR/sessions"
PROJECTS_DIR="$CLAUDE_DIR/projects"

# Convert cwd to claude's project dir name: /home/foo/bar -> -home-foo-bar
project_dir=$(echo "$PWD" | sed 's|^/||; s|/|-|g; s|^|-|')
project_path="$PROJECTS_DIR/$project_dir"

[[ -d "$project_path" ]] || exit 1

# Find the most recently modified .jsonl session file
latest=$(ls -t "$project_path"/*.jsonl 2>/dev/null | head -1)
[[ -n "$latest" ]] || exit 1

session_id=$(basename "$latest" .jsonl)

# Count user messages (conversation turns)
msg_count=$(grep -c '"type":\s*"user"' "$latest" 2>/dev/null || echo 0)
[[ "$msg_count" -gt 0 ]] 2>/dev/null || exit 1

# Smart relative time from file mtime
mod_epoch=$(stat -c %Y "$latest")
now=$(date +%s)
diff=$((now - mod_epoch))

if (( diff < 60 )); then
    age="now"
elif (( diff < 3600 )); then
    age="$((diff / 60))m"
elif (( diff < 86400 )); then
    age="$((diff / 3600))h"
elif (( diff < 604800 )); then
    age="$((diff / 86400))d"
else
    age="$((diff / 604800))w"
fi

# Check if session is active by finding its PID in session files
active=""
for sf in "$SESSIONS_DIR"/*.json; do
    [[ -f "$sf" ]] || continue
    if grep -q "$session_id" "$sf" 2>/dev/null; then
        pid=$(basename "$sf" .json)
        if kill -0 "$pid" 2>/dev/null; then
            active="true"
        fi
        break
    fi
done

# Output: e.g. "✽ 12msg 3d" or "✽ 12msg ✳" (active)
if [[ "$active" == "true" ]]; then
    echo "✽ ${msg_count}msg ✳"
else
    echo "✽ ${msg_count}msg ${age}"
fi
