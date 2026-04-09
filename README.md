# dotfiles

Personal dotfiles for macOS (Apple Silicon and Intel), managed with [GNU Stow](https://www.gnu.org/software/stow/) and a Makefile.

## Packages Overview

- [Homebrew](https://brew.sh) (packages: [Brewfile](./install/Brewfile))
- [Homebrew Cask](https://github.com/Homebrew/homebrew-cask) (apps: [Caskfile](./install/Caskfile))
- [Oh My Zsh](https://ohmyz.sh) with plugins
- [VS Code](https://code.visualstudio.com) (extensions: [Codefile](./install/Codefile))
- [asdf](https://asdf-vm.com) for runtime version management (nodejs, python, golang, ruby, air)
- [Claude Code](https://claude.ai/claude-code) (settings, statusline, skills)

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

This will install Homebrew packages, cask apps, Oh My Zsh (with plugins), symlink configs, install asdf plugins and runtimes, install Go tools, install VS Code extensions, and link Claude Code settings and skills.

## Post-Install

These steps can't be automated and need to be done manually:

```sh
# Create ~/.config/git/local with machine-specific git settings
cat > ~/.config/git/local << 'EOF'
[user]
	email = your@email.com
	signingkey = ~/.ssh/id_ed25519.pub
EOF
```

Populate a file for tokens and secrets (not committed):

```sh
touch ~/dotfiles/system/.exports
# Example: export GITHUB_TOKEN=abc
```

Log into apps: 1Password, Arc, Slack, Spotify, Docker, etc.

## Keeping Up to Date

On every new terminal, dotfiles will check for updates every 13 days and prompt:

```
[dotfiles] Updates available. Would you like to update? [Y/n]
```

You can also update manually at any time:

```sh
dot update
```

## Useful Commands

### `dot` CLI

```sh
dot install   # Install packages from Brewfile and Caskfile (initial setup)
dot update    # Update dotfiles, Homebrew packages, Oh My Zsh, and VS Code extensions
dot health    # Check symlinks, required tools, and asdf runtimes
dot clean     # Clean up caches (Homebrew, gem)
dot edit      # Open dotfiles in VS Code
dot help      # Show available commands
```

### Makefile targets

```sh
make                    # Full setup (same as make macos)
make brew-packages      # Install Homebrew packages from Brewfile
make cask-apps          # Install cask apps from Caskfile
make oh-my-zsh          # Install Oh My Zsh and plugins
make asdf-plugins       # Install asdf plugins and runtimes from .tool-versions
make go-tools           # Install Go tools (gopls)
make link               # Symlink all dotfiles via stow + individual links
make link-claude        # Link Claude Code settings, statusline, and skills
make unlink             # Remove symlinked dotfiles
make vscode-extensions  # Install VS Code extensions from Codefile
```

## Customization

- **Brew packages**: Add to `install/Brewfile`, then run `make brew-packages`
- **Cask apps**: Add to `install/Caskfile`, then run `make cask-apps`
- **VS Code extensions**: Add to `install/Codefile`, then run `make vscode-extensions`
- **asdf runtimes**: Edit `runcom/.tool-versions`, then run `make asdf-plugins`
- **Aliases**: Edit `system/.alias`
- **Functions**: Edit `system/.function`
- **Environment variables**: Edit `system/.env`
- **PATH**: Edit `system/.path`
- **Claude Code settings**: Edit `claude/settings.json`
- **Claude Code skills**: Add to `claude/skills/`

## Credits

Many thanks to the [dotfiles community](https://dotfiles.github.io).
