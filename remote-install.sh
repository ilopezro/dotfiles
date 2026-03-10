#!/usr/bin/env bash

SOURCE="https://github.com/ilopezro/dotfiles"
TARBALL="$SOURCE/tarball/main"
TARGET="$HOME/dotfiles"

if [ -d "$TARGET" ]; then
  echo "Dotfiles already installed at $TARGET"
  exit 1
fi

if command -v git &>/dev/null; then
  CMD="git clone $SOURCE $TARGET"
elif command -v curl &>/dev/null; then
  CMD="curl -#L $TARBALL | tar -xzv -C $TARGET --strip-components=1"
elif command -v wget &>/dev/null; then
  CMD="wget --no-check-certificate -O - $TARBALL | tar -xzv -C $TARGET --strip-components=1"
else
  echo "No git, curl, or wget available. Aborting."
  exit 1
fi

echo "Installing dotfiles..."
mkdir -p "$TARGET"
eval "$CMD"

echo "Done! Now run:"
echo "  cd ~/dotfiles && make"
