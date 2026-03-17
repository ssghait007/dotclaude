#!/bin/bash
COMMAND=$(jq -r '.tool_input.command // empty')

# Ask: aws s3 rb (remove bucket)
if echo "$COMMAND" | grep -qE 'aws\s+s3\s+rb\s'; then
  jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:"Deleting an S3 bucket is irreversible. Confirm before executing."}}'
  exit 0
fi

# Ask: aws ec2 terminate-instances
if echo "$COMMAND" | grep -qE 'aws\s+ec2\s+terminate-instances'; then
  jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:"Terminated EC2 instances cannot be recovered. Confirm before executing."}}'
  exit 0
fi

# Ask: aws iam create-access-key
if echo "$COMMAND" | grep -qE 'aws\s+iam\s+create-access-key'; then
  jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:"Long-lived access keys are a security risk. Prefer IAM roles or SSO. Confirm if needed."}}'
  exit 0
fi

exit 0
