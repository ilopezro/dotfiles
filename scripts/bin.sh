fancy_echo "Installing scripts to $HOME/bin..."
mkdir -p $HOME/bin
ln -s $(pwd)/bin/* $HOME/bin
