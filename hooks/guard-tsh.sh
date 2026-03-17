#!/bin/bash
# Ask before executing tsh ssh commands containing dangerous subcommands
COMMAND=$(jq -r '.tool_input.command // empty')

if echo "$COMMAND" | grep -qE 'tsh\s+ssh\s+.*\b(kubectl\s+(delete|drain|cordon|scale|exec|edit)|helm\s+(delete|uninstall|rollback)|psql|drop\s+|truncate\s+|rm\s+-rf)'; then
  MATCHED=$(echo "$COMMAND" | grep -oE '(kubectl\s+(delete|drain|cordon|scale|exec|edit)|helm\s+(delete|uninstall|rollback)|psql|drop\s+|truncate\s+|rm\s+-rf)' | head -1)
  jq -n --arg reason "tsh ssh tunneling dangerous command: \`$MATCHED\`. Confirm before executing." \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$reason}}'
  exit 0
fi

exit 0
