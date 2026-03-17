#!/bin/bash
# Block `npx` → `bunx` and `npm` → `bun`
COMMAND=$(jq -r '.tool_input.command // empty')

if echo "$COMMAND" | grep -qE '(^|[[:space:]]|&&|\|\||;)npx[[:space:]]'; then
  jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"Use `bunx` instead of `npx`. This project uses Bun."}}'
  exit 0
fi

if echo "$COMMAND" | grep -qE '(^|[[:space:]]|&&|\|\||;)npm[[:space:]]'; then
  jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"Use `bun` instead of `npm`. This project uses Bun."}}'
  exit 0
fi

exit 0
