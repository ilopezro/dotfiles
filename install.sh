#!/bin/bash
# fancy_echo() {
#   local fmt="$1"; shift

#   # shellcheck disable=SC2059
#   printf "\n$fmt\n" "$@"
# }

# export -f fancy_echo

# source scripts/brew.sh
# source scripts/apps.sh
# source scripts/base-16.sh

# fancy_echo "Linking dotfiles into ~..."
# RCRC=rcrc rcup -v

# source scripts/asdf.sh
# source scripts/fonts.sh
# source scripts/bin.sh

# fancy_echo "Bootstrapped!"

set -e

echo "🔧 Starting dotfiles setup for Apple Silicon..."

# Function to install Homebrew for Apple Silicon (/opt/homebrew)
install_homebrew() {
  if ! command -v brew &> /dev/null; then
    echo "🍺 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Ensure Homebrew is set up for Apple Silicon
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    echo "🍺 Homebrew already installed. Updating..."
    brew update
  fi
}

# Function to install Oh My Zsh
install_oh_my_zsh() {
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "🌀 Installing Oh My Zsh..."
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  else
    echo "🌀 Oh My Zsh already installed."
  fi
}

# Function to install asdf
install_asdf() {
  if [ ! -d "$HOME/.asdf" ]; then
    echo "📦 Installing asdf..."
    git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1
  else
    echo "📦 asdf already installed."
  fi

  if ! grep -q 'asdf.sh' ~/.zshrc; then
    echo "🔌 Adding asdf initialization to .zshrc..."
    {
      echo -e "\n. \"$HOME/.asdf/asdf.sh\""
      echo ". \"$HOME/.asdf/completions/asdf.bash\""
    } >> ~/.zshrc
  fi
}

# Function to symlink dotfiles using stow
symlink_dotfiles() {
  echo "🔗 Symlinking dotfiles using stow..."
  # Loop through directories, skipping .git/ and any non-directory
  for dir in */ ; do
    [ "$dir" == ".git/" ] && continue
    stow "${dir%/}"
  done
}

# Run setup steps
install_homebrew
# install_oh_my_zsh
# install_asdf
# symlink_dotfiles

echo "✅ Dotfiles setup complete!"