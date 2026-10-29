# Shared output helpers for bin/dot, bin/cask-doctor, bin/macos-defaults, and the
# Makefile.
# Sourced, not executed. Uses the 16 ANSI colors so the terminal theme (Catppuccin
# via Ghostty) decides the actual shades and follows light/dark switches. Color is
# off when stdout is not a terminal or NO_COLOR is set; CLICOLOR_FORCE=1 keeps it
# on for captured output (`make demo` records it for the README GIF).

if [ -z "${NO_COLOR:-}" ] && { [ -n "${CLICOLOR_FORCE:-}" ] || { [ -t 1 ] && [ "${TERM:-}" != "dumb" ]; }; }; then
  _esc=$(printf '\033')
  C_RESET="${_esc}[0m"
  C_BOLD="${_esc}[1m"
  C_DIM="${_esc}[2m"
  C_RED="${_esc}[31m"
  C_GREEN="${_esc}[32m"
  C_YELLOW="${_esc}[33m"
  C_BLUE="${_esc}[34m"
  unset _esc
else
  C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE=''
fi

pass()    { printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
fail()    { printf '  %s✗%s %s\n' "$C_RED" "$C_RESET" "$*"; }
warn()    { printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
info()    { printf '  %s›%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
note()    { printf '  %s%s%s\n' "$C_DIM" "$*" "$C_RESET"; }
section() { printf '%s%s%s\n' "$C_BOLD" "$*" "$C_RESET"; }
step()    { printf '%s==>%s %s%s%s\n' "$C_BLUE" "$C_RESET" "$C_BOLD" "$*" "$C_RESET"; }
success() { printf '%s%s%s\n' "$C_GREEN" "$*" "$C_RESET"; }
error()   { printf '%s%s%s\n' "$C_RED" "$*" "$C_RESET"; }
