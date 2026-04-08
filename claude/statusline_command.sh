#!/bin/bash
# Claude Code status line: robbyrussell-themed context window usage

input=$(cat)

used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
rate_5h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
rate_7d=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

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

# Build rate limit string with color thresholds (same as context: <=20 green, <=50 yellow, else red)
rate_color() {
  local pct="$1"
  if [ "$pct" -le 20 ]; then echo "$GREEN"
  elif [ "$pct" -le 50 ]; then echo "$YELLOW"
  else echo "$RED"
  fi
}

rate_info=""
if [ -n "$rate_5h" ]; then
  r5=$(printf "%.0f" "$rate_5h")
  c=$(rate_color "$r5")
  rate_info="${rate_info}${BLUE}5h:${RESET}${c}${r5}%${RESET}"
fi
if [ -n "$rate_7d" ]; then
  r7=$(printf "%.0f" "$rate_7d")
  c=$(rate_color "$r7")
  [ -n "$rate_info" ] && rate_info="${rate_info} "
  rate_info="${rate_info}${BLUE}7d:${RESET}${c}${r7}%${RESET}"
fi

if [ -n "$used" ] && [ -n "$remaining" ]; then
  used_int=$(printf "%.0f" "$used")
  remaining_int=$(printf "%.0f" "$remaining")

  # Color-code used percentage: 0-20 green, 21-50 yellow, 51-100 red
  if [ "$used_int" -le 20 ]; then
    USED_COLOR="$GREEN"
  elif [ "$used_int" -le 50 ]; then
    USED_COLOR="$YELLOW"
  else
    USED_COLOR="$RED"
  fi

  # Color-code remaining percentage (inverse of used): 80-100 green, 50-79 yellow, 0-49 red
  if [ "$remaining_int" -ge 80 ]; then
    REMAINING_COLOR="$GREEN"
  elif [ "$remaining_int" -ge 50 ]; then
    REMAINING_COLOR="$YELLOW"
  else
    REMAINING_COLOR="$RED"
  fi

  bar=$(build_bar "$used_int")
  printf "${GREEN}➜${RESET}  ${CYAN}%s${RESET}  ${BLUE}|${RESET}  ${BLUE}[${USED_COLOR}%s${BLUE}]${RESET} ${USED_COLOR}%s%%${RESET} used / ${REMAINING_COLOR}%s%%${RESET} remaining  ${BLUE}|${RESET}  ${YELLOW}%s${RESET}" \
    "$model" "$bar" "$used_int" "$remaining_int" "$cost_fmt"
  if [ -n "$rate_info" ]; then
    printf "  ${BLUE}|${RESET}  "
    printf "%b" "$rate_info"
  fi
else
  printf "${GREEN}➜${RESET}  ${CYAN}%s${RESET}  ${BLUE}|${RESET}  ${BLUE}[${YELLOW}-------------------${BLUE}]${RESET} no usage yet  ${BLUE}|${RESET}  ${YELLOW}%s${RESET}" "$model" "$cost_fmt"
  if [ -n "$rate_info" ]; then
    printf "  ${BLUE}|${RESET}  "
    printf "%b" "$rate_info"
  fi
fi
