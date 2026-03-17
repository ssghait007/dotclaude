#!/usr/bin/env bash
set -euo pipefail

# Read JSON once and extract all fields
eval "$(jq -r '@sh "
  model_name=\(.model.display_name // "Unknown")
  current_dir=\(.workspace.current_dir // "")
  used_pct=\((.context_window.used_percentage // 0) | floor)
  total_in=\(.context_window.total_input_tokens // 0)
  total_out=\(.context_window.total_output_tokens // 0)
  lines_added=\(.cost.total_lines_added // 0)
  lines_removed=\(.cost.total_lines_removed // 0)
"')"

# Format numbers with k/M suffixes
fmt_num() {
  local n=$1
  if [ "$n" -ge 1000000 ]; then
    printf "%.1fM" "$(echo "scale=1; $n / 1000000" | bc)"
  elif [ "$n" -ge 1000 ]; then
    printf "%.1fk" "$(echo "scale=1; $n / 1000" | bc)"
  else
    printf "%d" "$n"
  fi
}

# Get folder name
folder_name="${current_dir##*/}"
[ -z "$folder_name" ] && folder_name="~"

# Git info with caching
cache_file="/tmp/claude-statusline-git-cache"
cache_valid=false
if [ -f "$cache_file" ]; then
  cache_age=$(($(date +%s) - $(stat -f %m "$cache_file" 2>/dev/null || echo 0)))
  [ "$cache_age" -lt 5 ] && cache_valid=true
fi

if [ "$cache_valid" = true ]; then
  source "$cache_file"
else
  if git -C "$current_dir" rev-parse --git-dir >/dev/null 2>&1; then
    repo_name=$(git -C "$current_dir" remote get-url origin 2>/dev/null | sed -E 's#.*[:/]([^/]+/[^/]+)(\.git)?$#\1#' | sed 's/\.git$//')
    branch=$(git -C "$current_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

    # Cache results
    {
      echo "repo_name='$repo_name'"
      echo "branch='$branch'"
    } > "$cache_file"
  else
    repo_name=""
    branch=""
    echo "repo_name=''" > "$cache_file"
    echo "branch=''" >> "$cache_file"
  fi
fi

cyan='\033[36m'
dim='\033[2m'
green='\033[32m'
red='\033[31m'
reset='\033[0m'

# LINE 1: Model | Progress bar | Tokens
bar_width=15
filled=$((used_pct * bar_width / 100))
[ "$filled" -gt "$bar_width" ] && filled=$bar_width

bar=""
for ((i=0; i<filled; i++)); do bar="${bar}█"; done
bar="${bar}${dim}"
for ((i=filled; i<bar_width; i++)); do bar="${bar}░"; done
bar="${bar}${reset}"

tokens_in=$(fmt_num "$total_in")
tokens_out=$(fmt_num "$total_out")

sep="${dim}   ›   ${reset}"

line1="${cyan}${model_name}${reset}${sep}${bar} ${used_pct}%${sep}${tokens_in}/${tokens_out}"

# LINE 2: Folder · repo:branch · Diff stats
line2="${folder_name}"

if [ -n "$repo_name" ] && [ -n "$branch" ]; then
  line2="${line2}${sep}${repo_name}:${branch}"
fi

if [ "$lines_added" -gt 0 ] || [ "$lines_removed" -gt 0 ]; then
  line2="${line2}${sep}"
  [ "$lines_added" -gt 0 ] && line2="${line2}${green}↑${reset}${lines_added}"
  [ "$lines_removed" -gt 0 ] && line2="${line2} ${red}↓${reset}${lines_removed}"
fi

# Output both lines
printf '%b\n' "$line1"
printf '%b\n' "$line2"

# ── Usage bars (5-hour + weekly) ──────────────────────────────
usage_cache="/tmp/claude-usage-cache.json"
usage_cache_ttl=60
backoff_file="/tmp/claude-usage-backoff"

now_epoch=$(date +%s)
fetch_usage=false
if [ -f "$usage_cache" ]; then
  usage_age=$((now_epoch - $(stat -f %m "$usage_cache" 2>/dev/null || echo 0)))
  [ "$usage_age" -ge "$usage_cache_ttl" ] && fetch_usage=true
else
  fetch_usage=true
fi

# Respect backoff after 429s
if [ "$fetch_usage" = true ] && [ -f "$backoff_file" ]; then
  backoff_until=$(cat "$backoff_file" 2>/dev/null || echo 0)
  if [ "$now_epoch" -lt "$backoff_until" ]; then
    fetch_usage=false  # still in backoff period
  fi
fi

if [ "$fetch_usage" = true ]; then
  token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null || true)
  if [ -n "$token" ]; then
    http_code=""
    resp=$(curl -s --max-time 3 -w '\n%{http_code}' \
      -H "Authorization: Bearer $token" \
      -H "anthropic-beta: oauth-2025-04-20" \
      "https://api.anthropic.com/api/oauth/usage" 2>/dev/null || true)
    if [ -n "$resp" ]; then
      http_code=$(echo "$resp" | tail -1)
      resp=$(echo "$resp" | sed '$d')
    fi
    if [ -n "$resp" ] && echo "$resp" | jq -e '.five_hour' >/dev/null 2>&1; then
      echo "$resp" > "$usage_cache"
      rm -f "$backoff_file"  # success — clear backoff
    elif [ "$http_code" = "429" ]; then
      # Exponential backoff: read current backoff duration, double it (cap at 600s)
      prev_dur=60
      if [ -f "$backoff_file" ]; then
        prev_end=$(cat "$backoff_file" 2>/dev/null || echo 0)
        prev_dur=$(( prev_end - now_epoch ))
        [ "$prev_dur" -lt 60 ] && prev_dur=60
      fi
      next_dur=$(( prev_dur * 2 ))
      [ "$next_dur" -gt 600 ] && next_dur=600
      echo $(( now_epoch + next_dur )) > "$backoff_file"
    fi
  fi
fi

if [ -f "$usage_cache" ]; then
  # Check staleness — warn if cache is older than 2x TTL
  cache_mtime=$(stat -f %m "$usage_cache" 2>/dev/null || echo "$now_epoch")
  cache_age_s=$((now_epoch - cache_mtime))
  stale_marker=""
  if [ "$cache_age_s" -gt $((usage_cache_ttl * 2)) ]; then
    stale_mins=$((cache_age_s / 60))
    stale_marker=" ${dim}(${stale_mins}m old)${reset}"
  fi

  five_pct=$(jq -r '.five_hour.utilization // 0' "$usage_cache" | cut -d. -f1)
  five_reset=$(jq -r '.five_hour.resets_at // empty' "$usage_cache")
  week_pct=$(jq -r '.seven_day.utilization // 0' "$usage_cache" | cut -d. -f1)
  week_reset=$(jq -r '.seven_day.resets_at // empty' "$usage_cache")
  sonnet_pct=$(jq -r '.seven_day_sonnet.utilization // 0' "$usage_cache" | cut -d. -f1)
  sonnet_reset=$(jq -r '.seven_day_sonnet.resets_at // empty' "$usage_cache")

  # Progress bar helper: render_bar <pct> <width>
  render_bar() {
    local pct=$1 width=${2:-10}
    local filled=$((pct * width / 100))
    [ "$filled" -gt "$width" ] && filled=$width
    local bar=""
    for ((i=0; i<filled; i++)); do bar="${bar}●"; done
    for ((i=filled; i<width; i++)); do bar="${bar}○"; done
    echo "$bar"
  }

  # Format reset time (API returns UTC, convert to local)
  fmt_reset() {
    local iso=$1
    if [ -z "$iso" ]; then echo "—"; return; fi
    # Strip fractional seconds and timezone, parse as UTC to get epoch
    local stripped="${iso%%.*}"
    local epoch_reset epoch_now diff_s
    epoch_reset=$(TZ=UTC date -jf "%Y-%m-%dT%H:%M:%S" "$stripped" "+%s" 2>/dev/null || echo 0)
    epoch_now=$(date +%s)
    diff_s=$((epoch_reset - epoch_now))
    if [ "$diff_s" -le 86400 ] && [ "$diff_s" -gt 0 ]; then
      # Within 24h — show just time in local tz
      date -r "$epoch_reset" "+%-I:%M%p" 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "—"
    else
      # Further out — show date + time in local tz
      date -r "$epoch_reset" "+%b %-d, %-I:%M%p" 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "—"
    fi
  }

  five_bar=$(render_bar "$five_pct")
  week_bar=$(render_bar "$week_pct")
  sonnet_bar=$(render_bar "$sonnet_pct")
  five_time=$(fmt_reset "$five_reset")
  week_time=$(fmt_reset "$week_reset")
  sonnet_time=$(fmt_reset "$sonnet_reset")

  yellow='\033[33m'
  printf '%b\n' "${yellow}current  ${reset}${five_bar} ${five_pct}% ${dim}↻${reset} ${five_time}${stale_marker}"
  printf '%b\n' "${yellow}weekly   ${reset}${week_bar} ${week_pct}% ${dim}↻${reset} ${week_time}${stale_marker}"
  printf '%b\n' "${yellow}weekly(s)${reset} ${sonnet_bar} ${sonnet_pct}% ${dim}↻${reset} ${sonnet_time}${stale_marker}"
fi
