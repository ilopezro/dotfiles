# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

COMPLETION_WAITING_DOTS="true"

plugins=(git asdf zsh-autosuggestions zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

fpath=($HOME/dotfiles/completions /opt/homebrew/share/zsh/site-functions ${ASDF_DATA_DIR:-$HOME/.asdf}/completions $fpath)
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select

# Source dotfiles system config
for DOTFILE in "$HOME/dotfiles/system"/.*; do
  [ -f "$DOTFILE" ] && source "$DOTFILE"
done
