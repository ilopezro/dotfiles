# dotfiles

Personal dotfiles for macOS (Apple Silicon and Intel), managed with [GNU Stow](https://www.gnu.org/software/stow/) and a Makefile.

## Packages Overview

- [Homebrew](https://brew.sh) (packages: [Brewfile](./install/Brewfile))
- [Homebrew Cask](https://github.com/Homebrew/homebrew-cask) (apps: [Caskfile](./install/Caskfile))
- [Oh My Zsh](https://ohmyz.sh) with plugins
- [VS Code](https://code.visualstudio.com) (extensions: [Codefile](./install/Codefile))
- [asdf](https://asdf-vm.com) for runtime version management

## Fresh Install

On a sparkling fresh installation of macOS:

```sh
# 1. Install macOS updates and Xcode Command Line Tools
sudo softwareupdate -i -a
xcode-select --install
```

Then either install with `curl`:

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/ilopezro/dotfiles/main/remote-install.sh)
cd ~/dotfiles && make
```

Or clone manually:

```sh
git clone https://github.com/ilopezro/dotfiles.git ~/dotfiles
cd ~/dotfiles && make
```

Running `make` is idempotent — it's safe to run multiple times.

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

Populate a file for tokens and secrets (not committed):

```sh
touch ~/dotfiles/system/.exports
# Example: export GITHUB_TOKEN=abc
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

## Credits

Many thanks to the [dotfiles community](https://dotfiles.github.io).
