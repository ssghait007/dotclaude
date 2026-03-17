#!/bin/bash
# Ask before executing dangerous kubectl commands
COMMAND=$(jq -r '.tool_input.command // empty')

if echo "$COMMAND" | grep -qE 'kubectl\s+(delete|drain|cordon|scale\s+.*replicas=0|exec|edit|rollout\s+undo)'; then
  MATCHED=$(echo "$COMMAND" | grep -oE 'kubectl\s+(delete|drain|cordon|scale\s+.*replicas=0|exec|edit|rollout\s+undo)')
  jq -n --arg reason "Dangerous kubectl command detected: \`$MATCHED\`. Confirm before executing." \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$reason}}'
  exit 0
fi

exit 0
