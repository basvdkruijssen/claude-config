#!/usr/bin/env bash
# Claude Code statusLine: shows current context usage, bottom-left,
# matching the accounting used by the native /context command.
# Reads the session JSON Claude Code sends on stdin.

input=$(cat)

if command -v jq >/dev/null 2>&1; then
  used_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
  used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
else
  # Fallback if jq isn't available: crude JSON field extraction.
  used_tokens=$(echo "$input" | grep -o '"total_input_tokens"[[:space:]]*:[[:space:]]*[0-9]*' | head -1 | grep -o '[0-9]*$')
  used_pct=$(echo "$input" | grep -o '"used_percentage"[[:space:]]*:[[:space:]]*[0-9.]*' | head -1 | grep -o '[0-9.]*$')
fi

if [ -z "$used_tokens" ] || [ "$used_tokens" = "null" ]; then
  echo "context: n/a"
  exit 0
fi

# Format token count like "12.5k" (or plain number under 1000).
formatted_tokens=$(awk -v n="$used_tokens" 'BEGIN {
  if (n >= 1000) { printf "%.1fk", n / 1000 } else { printf "%d", n }
}')

if [ -n "$used_pct" ] && [ "$used_pct" != "null" ]; then
  formatted_pct=$(awk -v p="$used_pct" 'BEGIN { printf "%.1f", p }')
  printf "%s (%s%%)" "$formatted_tokens" "$formatted_pct"
else
  printf "%s" "$formatted_tokens"
fi
