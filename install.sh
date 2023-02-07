#!/bin/sh

set -e

fancy_echo() {
  local fmt="$1"; shift

  # shellcheck disable=SC2059
  printf "\n$fmt\n" "$@"
}

export -f fancy_echo

source scripts/brew.sh
source scripts/apps.sh
source scripts/base-16.sh

fancy_echo "Linking dotfiles into ~..."
RCRC=rcrc rcup -v

source scripts/asdf.sh
source scripts/fonts.sh
source scripts/bin.sh

fancy_echo "Bootstrapped!"