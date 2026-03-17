#!/usr/bin/env bash
# UserPromptSubmit hook: block if weekly usage limit is at 100%
# Throttled to check once every 5 minutes — reads from statusline cache (no extra API calls)

THROTTLE_FILE="/tmp/claude-usage-limit-lastcheck"
THROTTLE_SECS=300  # 5 minutes
USAGE_CACHE="/tmp/claude-usage-cache.json"
SETTINGS="$HOME/.claude/settings.json"

now=$(date +%s)

# --- Throttle: skip if checked recently ---
if [ -f "$THROTTLE_FILE" ]; then
  last=$(cat "$THROTTLE_FILE" 2>/dev/null || echo 0)
  elapsed=$(( now - last ))
  if [ "$elapsed" -lt "$THROTTLE_SECS" ]; then
    exit 0
  fi
fi

# Mark this check
echo "$now" > "$THROTTLE_FILE"

# --- No cache = nothing to check ---
if [ ! -f "$USAGE_CACHE" ]; then
  exit 0
fi

# --- Detect current model from global settings ---
model=$(jq -r '.model // "sonnet"' "$SETTINGS" 2>/dev/null || echo "sonnet")

# --- Select the right utilization field ---
if echo "$model" | grep -qi "sonnet"; then
  pct=$(jq -r '(.seven_day_sonnet.utilization // 0) | floor' "$USAGE_CACHE" 2>/dev/null || echo 0)
  limit_name="weekly(s) [Sonnet]"
else
  pct=$(jq -r '(.seven_day.utilization // 0) | floor' "$USAGE_CACHE" 2>/dev/null || echo 0)
  limit_name="weekly [non-Sonnet]"
fi

# --- Block at 100% ---
if [ "$pct" -ge 100 ]; then
  echo "Weekly usage limit reached: $limit_name is at ${pct}%. Stop to avoid burning extra credits." >&2
  exit 2
fi

exit 0
