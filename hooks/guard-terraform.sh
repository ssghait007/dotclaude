#!/bin/bash
COMMAND=$(jq -r '.tool_input.command // empty')

# Deny: terraform destroy
if echo "$COMMAND" | grep -qE 'terraform\s+destroy'; then
  jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"`terraform destroy` is blocked. Use `terraform plan -destroy` to review first."}}'
  exit 0
fi

# Ask: terraform apply -auto-approve
if echo "$COMMAND" | grep -qE 'terraform\s+apply.*-auto-approve'; then
  jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:"`terraform apply -auto-approve` skips interactive review. Confirm you have verified the plan before proceeding."}}'
  exit 0
fi

# Ask: terraform state rm
if echo "$COMMAND" | grep -qE 'terraform\s+state\s+rm'; then
  jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:"Removing resources from Terraform state creates orphaned infra. Confirm before proceeding."}}'
  exit 0
fi

exit 0
