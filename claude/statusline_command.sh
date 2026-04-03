#!/bin/bash
# Claude Code status line: robbyrussell-themed context window usage

input=$(cat)

used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')

# Colors (robbyrussell theme)
GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[0;36m'
BLUE='\033[1;34m'
YELLOW='\033[0;33m'
RESET='\033[0m'

# Build progress bar (20 chars wide)
build_bar() {
  local pct="$1"
  local width=20
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))
  local bar=""
  local i
  for (( i=0; i<filled; i++ )); do bar="${bar}#"; done
  for (( i=0; i<empty; i++ )); do  bar="${bar}-"; done
  echo "$bar"
}

cost_fmt=$(printf '$%.2f' "${cost:-0}")

if [ -n "$used" ] && [ -n "$remaining" ]; then
  used_int=$(printf "%.0f" "$used")
  remaining_int=$(printf "%.0f" "$remaining")
  bar=$(build_bar "$used_int")
  printf "${GREEN}➜${RESET}  ${CYAN}%s${RESET}  ${BLUE}|${RESET}  ${BLUE}[${YELLOW}%s${BLUE}]${RESET} ${RED}%s%%${RESET} used / ${GREEN}%s%%${RESET} remaining  ${BLUE}|${RESET}  ${YELLOW}%s${RESET}" \
    "$model" "$bar" "$used_int" "$remaining_int" "$cost_fmt"
else
  printf "${GREEN}➜${RESET}  ${CYAN}%s${RESET}  ${BLUE}|${RESET}  ${BLUE}[${YELLOW}-------------------${BLUE}]${RESET} no usage yet  ${BLUE}|${RESET}  ${YELLOW}%s${RESET}" "$model" "$cost_fmt"
fi
