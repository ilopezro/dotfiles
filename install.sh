#!/bin/sh

set -e

fancy_echo() {
  local fmt="$1"; shift

  # shellcheck disable=SC2059
  printf "\n$fmt\n" "$@"
}

export -f fancy_echo

source scripts/brew.sh

fancy_echo "Linking dotfiles into ~..."
RCRC=rcrc rcup -v
