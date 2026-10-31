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
# `make <Tab>` offers only runnable targets, in any project. Without these, zsh also
# lists every variable (for `make VAR=value`) and every file, and it reads the
# Makefile as raw text, so a rule named `$(VAR):` shows up unexpanded. call-command
# asks make itself (`make -nsp`, a dry run) for the evaluated target list instead;
# path-like and dot-prefixed targets are build files and internals, not commands.
zstyle ':completion:*:*:make:*' tag-order 'targets'
zstyle ':completion:*:make:*:targets' call-command true
zstyle ':completion:*:*:make:*:targets' ignored-patterns '*/*' '.*'

# Source dotfiles system config
for DOTFILE in "$HOME/dotfiles/system"/.*; do
  [ -f "$DOTFILE" ] && source "$DOTFILE"
done
source ~/.safe-chain/scripts/init-posix.sh # Safe-chain Zsh initialization script

# Added by Devin
export PATH="$HOME/.codeium/windsurf/bin:$PATH"
