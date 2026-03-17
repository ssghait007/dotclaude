#!/bin/bash
# Block `git push` without explicit `origin <branch>`
# Catches: git push, git push --no-verify, git push -f, etc.
# Allows:  git push origin main, git push -u origin main, git push origin main --no-verify
COMMAND=$(jq -r '.tool_input.command // empty')

if echo "$COMMAND" | grep -qE '(^|&&\s*|;\s*)git\s+push' && ! echo "$COMMAND" | grep -qF 'origin'; then
  jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"Use `git push origin <branch_name>` instead. Always specify the remote and branch explicitly."}}'
  exit 0
fi

exit 0
