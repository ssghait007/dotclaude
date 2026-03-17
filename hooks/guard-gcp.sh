#!/bin/bash
COMMAND=$(jq -r '.tool_input.command // empty')

# Ask: gcloud projects delete
if echo "$COMMAND" | grep -qE 'gcloud\s+projects\s+delete'; then
  jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:"Deleting a GCP project destroys everything in it. Confirm before executing."}}'
  exit 0
fi

# Ask: gsutil rm -r
if echo "$COMMAND" | grep -qE 'gsutil\s+rm\s+-r'; then
  jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:"Recursive GCS bucket deletion is irreversible. Confirm before executing."}}'
  exit 0
fi

exit 0
