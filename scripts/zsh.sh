fancy_echo "Changing your shell to zsh ..."
if ! grep "$(which zsh)" /etc/shells; then
  sudo sh -c 'echo "$(which zsh)" >> /etc/shells'
fi
# chsh -s "$(which zsh)"

fancy_echo "Installing zgen..."
if test -e ~/.zgen/zgen.zsh; then
  fancy_echo "zgen installed, updating..."
  echo "here"
  source ~/.zgen/zgen.zsh
  echo "here"
  zgen selfupdate
  echo "here"
  zgen update
else
  git clone https://github.com/tarjoilija/zgen.git "${HOME}/.zgen"
fi
