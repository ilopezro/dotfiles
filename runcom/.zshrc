# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

plugins=(git asdf zsh-autosuggestions zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

# Source dotfiles system config
for DOTFILE in "$HOME/dotfiles/system"/.*; do
  [ -f "$DOTFILE" ] && source "$DOTFILE"
done
