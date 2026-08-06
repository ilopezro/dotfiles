# dotfiles

Personal dotfiles for macOS (Apple Silicon and Intel), managed with [GNU Stow](https://www.gnu.org/software/stow/) and a Makefile.

## Packages Overview

- [Homebrew](https://brew.sh) (packages: [Brewfile](./install/Brewfile))
- [Homebrew Cask](https://github.com/Homebrew/homebrew-cask) (apps: [Caskfile](./install/Caskfile))
- [mas](https://github.com/mas-cli/mas) for Mac App Store apps (apps: [Masfile](./install/Masfile))
- [Oh My Zsh](https://ohmyz.sh) with plugins
- [VS Code](https://code.visualstudio.com) (extensions: [Codefile](./install/Codefile))
- [asdf](https://asdf-vm.com) for runtime version management (nodejs, python, golang, ruby, air, uv)
- Global npm tools (packages: [Npmfile](./install/Npmfile))
- [Claude Code](https://claude.ai/claude-code) (settings, statusline, skills, MCP servers: [Mcpfile](./install/Mcpfile))

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

This will install Homebrew packages, cask apps, Mac App Store apps, Oh My Zsh (with plugins), symlink configs, install asdf plugins and runtimes, install Go tools, install global npm tools, install VS Code extensions, link Claude Code settings and skills, and register Claude Code MCP servers.

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

Sign into the Mac App Store (App Store → Sign In) before running `make mas-apps`, so `mas` can install Mac App Store apps like Amphetamine. `mas` can only install apps already associated with your Apple ID.

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
dot install   # Install packages from Brewfile, Caskfile, and Npmfile, and MCP servers from Mcpfile (initial setup)
dot update    # Update dotfiles, Homebrew packages, Oh My Zsh, VS Code extensions, and npm tools
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
make mas-apps           # Install Mac App Store apps from Masfile (via mas)
make oh-my-zsh          # Install Oh My Zsh and plugins
make asdf-plugins       # Install asdf plugins and runtimes from .tool-versions
make go-tools           # Install Go tools (gopls)
make npm-tools          # Install global npm packages from Npmfile
make link               # Symlink all dotfiles via stow + individual links
make link-claude        # Link Claude Code settings, statusline, and skills
make claude-mcp         # Register Claude Code MCP servers from Mcpfile
make unlink             # Remove symlinked dotfiles
make vscode-extensions  # Install VS Code extensions from Codefile
```

## Customization

- **Brew packages**: Add to `install/Brewfile`, then run `make brew-packages`
- **Cask apps**: Add to `install/Caskfile`, then run `make cask-apps`
- **Mac App Store apps**: Add a `Name|id` line to `install/Masfile` (find the id with `mas search "Name"`), then run `make mas-apps`
- **VS Code extensions**: Add to `install/Codefile`, then run `make vscode-extensions`
- **asdf runtimes**: Edit `runcom/.tool-versions`, then run `make asdf-plugins`
- **Global npm tools**: Add to `install/Npmfile`, then run `make npm-tools`
- **Claude Code MCP servers**: Add a `name|command` line to `install/Mcpfile`, then run `make claude-mcp`
- **Aliases**: Edit `system/.alias`
- **Functions**: Edit `system/.function`
- **Environment variables**: Edit `system/.env`
- **PATH**: Edit `system/.path`
- **Claude Code settings**: Edit `claude/settings.json`
- **Claude Code skills**: Add to `claude/skills/`

## Credits

Many thanks to the [dotfiles community](https://dotfiles.github.io).
