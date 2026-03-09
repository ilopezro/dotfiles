# dotfiles

Personal dotfiles for macOS, managed with [GNU Stow](https://www.gnu.org/software/stow/) and a Makefile.

## Fresh Install

```sh
# 1. Install Xcode Command Line Tools
xcode-select --install

# 2. Clone and install
bash <(curl -fsSL https://raw.githubusercontent.com/ilopezro/dotfiles/main/remote-install.sh)
cd ~/dotfiles && make
```

This will install Homebrew packages, cask apps, Oh My Zsh (with plugins), symlink configs, and install VS Code extensions.

## Post-Install

These steps can't be automated and need to be done manually:

```sh
# Create ~/.config/git/local with machine-specific git settings
cat > ~/.config/git/local << 'EOF'
[user]
	email = your@email.com
	signingkey = ~/.ssh/id_ed25519.pub
EOF

# Set up asdf plugins
asdf plugin add nodejs
asdf plugin add ruby
asdf plugin add golang
asdf plugin add air https://github.com/ilopezro/asdf-air.git
# Then install versions as needed: asdf install nodejs latest
```

Log into apps: 1Password, Arc, Slack, Spotify, Docker, etc.

## Useful Commands

```sh
dot update    # Update Homebrew packages and Oh My Zsh
dot clean     # Clean up caches
dot edit      # Open dotfiles in VS Code
dot help      # Show available commands
```

## Customization

- **Brew packages**: Add to `install/Brewfile`, then run `make brew-packages`
- **Cask apps**: Add to `install/Caskfile`, then run `make cask-apps`
- **VS Code extensions**: Add to `install/Codefile`, then run `make vscode-extensions`
- **Aliases**: Edit `system/.alias`
- **Functions**: Edit `system/.function`
- **Environment variables**: Edit `system/.env`
- **PATH**: Edit `system/.path`
