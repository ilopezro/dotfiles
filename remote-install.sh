#!/usr/bin/env bash

SOURCE="https://github.com/ilopezro/dotfiles"
TARGET="$HOME/dotfiles"

if [ -d "$TARGET" ]; then
  echo "Dotfiles already installed at $TARGET"
  exit 1
fi

if command -v git &>/dev/null; then
  echo "Cloning dotfiles..."
  git clone "$SOURCE" "$TARGET"
else
  echo "Git is not installed. Install Xcode CLI tools first:"
  echo "  xcode-select --install"
  exit 1
fi

echo "Done! Now run:"
echo "  cd ~/dotfiles && make"
