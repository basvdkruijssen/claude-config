#!/usr/bin/env bash
# Claude Code statusLine: model, cwd, git repo/branch, context usage and
# 5h/7d rate-limit usage, on two colored lines.
# Reads the session JSON Claude Code sends on stdin.

input=$(cat)

RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[36m'
BLUE='\033[34m'
MAGENTA='\033[35m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
GRAY='\033[90m'

# Color a percentage: green < 50, yellow < 80, red >= 80.
pct_color() {
  local pct="$1"
  if [ -z "$pct" ]; then
    echo "$GRAY"
  elif awk -v p="$pct" 'BEGIN { exit !(p >= 80) }'; then
    echo "$RED"
  elif awk -v p="$pct" 'BEGIN { exit !(p >= 50) }'; then
    echo "$YELLOW"
  else
    echo "$GREEN"
  fi
}

# "1h30m" until an epoch-seconds instant; empty if unknown/past.
until_str() {
  local resets_at="$1"
  { [ -z "$resets_at" ] || [ "$resets_at" = "null" ]; } && return
  local now secs
  now=$(date +%s)
  secs=$((resets_at - now))
  [ "$secs" -le 0 ] && return
  awk -v s="$secs" 'BEGIN {
    h = int(s / 3600); m = int((s % 3600) / 60)
    if (h > 0) printf "%dh%dm", h, m; else printf "%dm", m
  }'
}

# Pick a JSON extractor: jq if present, else a python/python3 that actually
# runs (a Windows Store app-execution alias can satisfy `command -v` but
# error when invoked), else neither.
JQ=""
command -v jq >/dev/null 2>&1 && JQ="jq"

PY=""
if [ -z "$JQ" ]; then
  for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c "1" >/dev/null 2>&1; then
      PY="$candidate"
      break
    fi
  done
fi

extract_fields() {
  if [ -n "$JQ" ]; then
    echo "$input" | jq -r '[
      (.model.display_name // .model.id // "unknown"),
      (.cwd // .workspace.current_dir // ""),
      (.context_window.total_input_tokens // empty),
      (.context_window.used_percentage // empty),
      (.rate_limits.five_hour.used_percentage // empty),
      (.rate_limits.five_hour.resets_at // empty),
      (.rate_limits.seven_day.used_percentage // empty),
      (.rate_limits.seven_day.resets_at // empty)
    ] | @tsv'
  elif [ -n "$PY" ]; then
    echo "$input" | "$PY" -c '
import json, sys

d = json.load(sys.stdin)

def g(*keys):
    cur = d
    for k in keys:
        if not isinstance(cur, dict):
            return ""
        cur = cur.get(k)
        if cur is None:
            return ""
    return cur

fields = [
    g("model", "display_name") or g("model", "id") or "unknown",
    g("cwd") or g("workspace", "current_dir") or "",
    g("context_window", "total_input_tokens"),
    g("context_window", "used_percentage"),
    g("rate_limits", "five_hour", "used_percentage"),
    g("rate_limits", "five_hour", "resets_at"),
    g("rate_limits", "seven_day", "used_percentage"),
    g("rate_limits", "seven_day", "resets_at"),
]
print("\t".join(str(f) for f in fields))
'
  fi
}

if [ -z "$JQ" ] && [ -z "$PY" ]; then
  # Neither available: degrade to the original context-only line via grep.
  used_tokens=$(echo "$input" | grep -o '"total_input_tokens"[[:space:]]*:[[:space:]]*[0-9]*' | head -1 | grep -o '[0-9]*$')
  used_pct=$(echo "$input" | grep -o '"used_percentage"[[:space:]]*:[[:space:]]*[0-9.]*' | head -1 | grep -o '[0-9.]*$')
  if [ -z "$used_tokens" ] || [ "$used_tokens" = "null" ]; then
    echo "context: n/a (install jq or python for full statusline)"
  else
    formatted_tokens=$(awk -v n="$used_tokens" 'BEGIN { if (n >= 1000) printf "%.1fk", n/1000; else printf "%d", n }')
    printf "context: %s (%s%%) [install jq or python for full statusline]" "$formatted_tokens" "$used_pct"
  fi
  exit 0
fi

IFS=$'\t' read -r model_name cwd_path used_tokens used_pct five_pct five_reset seven_pct seven_reset <<EOF
$(extract_fields)
EOF

# --- Line 1: model, cwd, git repo/branch ---------------------------------

cwd_display="${cwd_path/#$HOME/\~}"

git_segment=""
if [ -n "$cwd_path" ] && git -C "$cwd_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  repo_name=$(basename "$(git -C "$cwd_path" rev-parse --show-toplevel 2>/dev/null)")
  branch=$(git -C "$cwd_path" branch --show-current 2>/dev/null)
  [ -z "$branch" ] && branch=$(git -C "$cwd_path" rev-parse --short HEAD 2>/dev/null)
  if [ -n "$repo_name" ]; then
    git_segment=$(printf "${GRAY} │ ${RESET}${MAGENTA}\xf0\x9f\x8c\xbf %s ${DIM}(%s)${RESET}" "$branch" "$repo_name")
  fi
fi

line1=$(printf "${CYAN}\xf0\x9f\xa4\x96 %s${RESET}${GRAY} │ ${RESET}${BLUE}\xf0\x9f\x93\x82 %s${RESET}%s" \
  "$model_name" "$cwd_display" "$git_segment")

# --- Line 2: context + rate limits ---------------------------------------

if [ -z "$used_tokens" ] || [ "$used_tokens" = "null" ]; then
  ctx_str="n/a"
else
  formatted_tokens=$(awk -v n="$used_tokens" 'BEGIN { if (n >= 1000) printf "%.1fk", n/1000; else printf "%d", n }')
  ctx_color=$(pct_color "$used_pct")
  ctx_str=$(printf "${ctx_color}%s%% ${DIM}(%s)${RESET}" "$used_pct" "$formatted_tokens")
fi

five_str="n/a"
if [ -n "$five_pct" ] && [ "$five_pct" != "null" ]; then
  five_color=$(pct_color "$five_pct")
  five_when=$(until_str "$five_reset")
  if [ -n "$five_when" ]; then
    five_str=$(printf "${five_color}%s%% ${DIM}(resets %s)${RESET}" "$five_pct" "$five_when")
  else
    five_str=$(printf "${five_color}%s%%${RESET}" "$five_pct")
  fi
fi

seven_str="n/a"
if [ -n "$seven_pct" ] && [ "$seven_pct" != "null" ]; then
  seven_color=$(pct_color "$seven_pct")
  seven_when=$(until_str "$seven_reset")
  if [ -n "$seven_when" ]; then
    seven_str=$(printf "${seven_color}%s%% ${DIM}(resets %s)${RESET}" "$seven_pct" "$seven_when")
  else
    seven_str=$(printf "${seven_color}%s%%${RESET}" "$seven_pct")
  fi
fi

line2=$(printf "${BOLD}\xf0\x9f\x93\x8a${RESET} %s${GRAY} │ ${RESET}${BOLD}\xe2\x8f\xb1\xef\xb8\x8f 5h${RESET} %s${GRAY} │ ${RESET}${BOLD}\xf0\x9f\x93\x85 7d${RESET} %s" \
  "$ctx_str" "$five_str" "$seven_str")

printf "%b\n%b" "$line1" "$line2"
