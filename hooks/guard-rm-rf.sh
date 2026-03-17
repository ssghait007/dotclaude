#!/bin/bash
# Ask before executing rm -rf
COMMAND=$(jq -r '.tool_input.command // empty')

if echo "$COMMAND" | grep -qE 'rm\s+(-rf|-r\s+-f|-f\s+-r)'; then
  jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:"Command contains `rm -rf`. Confirm before executing."}}'
  exit 0
fi

exit 0
