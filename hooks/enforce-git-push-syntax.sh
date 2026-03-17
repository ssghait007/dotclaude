#!/bin/bash
# Block bare `git push` — require `git push origin <branch>`
COMMAND=$(jq -r '.tool_input.command // empty')

if echo "$COMMAND" | grep -qE '^git\s+push\s*$'; then
  jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"Use `git push origin <branch_name>` instead of bare `git push`."}}'
  exit 0
fi

exit 0
