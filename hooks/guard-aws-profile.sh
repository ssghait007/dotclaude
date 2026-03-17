#!/bin/bash
COMMAND=$(jq -r '.tool_input.command // empty')

# Deny: aws commands without --profile or AWS_PROFILE
if echo "$COMMAND" | grep -qE '(^|&&\s*|;\s*)aws\s' && ! echo "$COMMAND" | grep -qF -- '--profile' && ! echo "$COMMAND" | grep -qE 'AWS_PROFILE='; then
  jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"AWS CLI requires `--profile` or `AWS_PROFILE=`. Add one to avoid using wrong account credentials."}}'
  exit 0
fi

exit 0
