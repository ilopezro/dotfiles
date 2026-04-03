# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

zstyle ':omz:update' mode disabled

COMPLETION_WAITING_DOTS="true"

plugins=(git asdf zsh-autosuggestions zsh-syntax-highlighting)

# fpath must be set before OMZ sources compinit
fpath=($HOME/dotfiles/completions /opt/homebrew/share/zsh/site-functions ${ASDF_DATA_DIR:-$HOME/.asdf}/completions $fpath)

source $ZSH/oh-my-zsh.sh

zstyle ':completion:*' menu select

# Source dotfiles system config
for DOTFILE in "$HOME/dotfiles/system"/.*; do
  [ -f "$DOTFILE" ] && source "$DOTFILE"
done
source ~/.safe-chain/scripts/init-posix.sh # Safe-chain Zsh initialization script
