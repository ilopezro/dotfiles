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
- [Claude Code](https://claude.ai/claude-code) (settings, statusline, skills, MCP servers: [Mcpfile](./install/Mcpfile), plugins: [Pluginfile](./install/Pluginfile))
- macOS login items (apps: [Loginfile](./install/Loginfile))
- macOS preferences via `defaults` (settings: [Defaultsfile](./install/Defaultsfile))

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

Running `make` is idempotent — it's safe to run multiple times, and re-running it after a failure picks up where it left off.

`make` runs each setup step in order and keeps going if one fails, then lists the failures at the end and exits non-zero. A single unreachable download or broken cask therefore can't stop `link`, `signers`, or the asdf runtimes from being set up. Fix the cause and run `make` again, or just the one step (`make cask-apps`).

Some steps need root — a few casks own symlinks outside the Homebrew prefix. `make` asks for your password once up front and keeps the credential warm for the whole run, so nothing stalls on a hidden prompt halfway through. With no terminal to prompt on (CI, cron, an unattended run), it says so and continues; run `sudo -v` beforehand if you want those steps to succeed.

This will install Homebrew packages, cask apps, Mac App Store apps, Oh My Zsh (with plugins), symlink configs, register this machine's SSH signing key, install asdf plugins and runtimes, install Go tools, install global npm tools, install VS Code extensions, link Claude Code settings and skills, and register Claude Code MCP servers.

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

Commits and tags are signed with your SSH key. `config/git/allowed_signers` is the shared allowlist used to *verify* those signatures, so it needs the public key of every machine you sign from. `make signers` (part of `make`) appends this machine's key if it's missing — commit and push the change so your other machines trust it too:

```sh
make signers
git -C ~/dotfiles add config/git/allowed_signers
git -C ~/dotfiles commit -m "chore: trust <machine> signing key"
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
dot install   # Install packages from Brewfile, Caskfile, and Npmfile, MCP servers from Mcpfile, and plugins from Pluginfile (initial setup)
dot update    # Update dotfiles, Homebrew packages, Oh My Zsh, VS Code extensions, npm tools, and Claude Code plugins
dot health    # Check symlinks, commit signing, required tools, macOS defaults, login items, Claude Code plugins, and asdf runtimes
dot clean     # Clean up caches (Homebrew, gem)
dot edit      # Open dotfiles in VS Code
dot help      # Show available commands
```

### Makefile targets

```sh
make                    # Full setup (same as make macos)
make brew-packages      # Install Homebrew packages from Brewfile
make cask-apps          # Install cask apps from Caskfile, then repair any whose artifacts are missing
make mas-apps           # Install Mac App Store apps from Masfile (via mas)
make oh-my-zsh          # Install Oh My Zsh and plugins
make asdf-plugins       # Install asdf plugins and runtimes from .tool-versions
make go-tools           # Install Go tools (gopls)
make npm-tools          # Install global npm packages from Npmfile
make link               # Symlink all dotfiles via stow + individual links from Linkfile
make signers            # Add this machine's SSH signing key to config/git/allowed_signers
make link-files         # Create only the individual symlinks listed in Linkfile
make claude-mcp         # Register Claude Code MCP servers from Mcpfile
make claude-plugins     # Install Claude Code plugins from Pluginfile
make unlink             # Remove symlinked dotfiles
make test-link          # Round-trip link/unlink in a throwaway HOME and verify teardown is complete
make vscode-extensions  # Install VS Code extensions from Codefile
make login-items        # Register macOS login items from Loginfile
make macos-defaults     # Apply macOS preferences from Defaultsfile
```

## Customization

- **Brew packages**: Add to `install/Brewfile`, then run `make brew-packages`
- **Cask apps**: Add to `install/Caskfile`, then run `make cask-apps`. A cask whose app was deleted out from under Homebrew (usually by an upgrade that failed partway) still reads as installed to `brew bundle`, so `make cask-apps` follows the bundle with `cask-doctor repair`, which checks that each cask's App and Binary artifacts really exist and reinstalls the ones that don't. `dot health` reports the same check without changing anything, and `bin/cask-doctor check` runs it on its own. Repair asks for your password up front when it needs one — some casks own symlinks outside the Homebrew prefix — and is safe to interrupt and re-run: it re-derives what is still broken on every invocation
- **Mac App Store apps**: Add a `Name|id` line to `install/Masfile` (find the id with `mas search "Name"`), then run `make mas-apps`
- **VS Code extensions**: Add to `install/Codefile`, then run `make vscode-extensions`
- **asdf runtimes**: Edit `runcom/.tool-versions`, then run `make asdf-plugins`
- **Global npm tools**: Add to `install/Npmfile`, then run `make npm-tools`
- **Claude Code MCP servers**: Add a `name|command` line to `install/Mcpfile`, then run `make claude-mcp`
- **Claude Code plugins**: Add a `plugin@marketplace|source` line to `install/Pluginfile`, then run `make claude-plugins`
- **Login items** (apps that open at login): Add the app's full `.app` path to `install/Loginfile`, then run `make login-items`. Items are added via System Events (login items live in the Background Task Management database, which `defaults` can't write), so the first run prompts once for Automation permission. Apps not yet installed are skipped; `dot health` checks each entry
- **macOS defaults** (Dock, Finder, and other `defaults`-backed settings): Add a `domain|key|type|value|restart` line to `install/Defaultsfile` (e.g. `com.apple.dock|autohide|bool|true|Dock`), then run `make macos-defaults`. Only values that differ are written, and the restart app (`-` for none) is only killed when something changed. `dot health` reports drift via `bin/macos-defaults check`
- **Individual symlinks** (anything not stowed): Add a `source|destination` line to `install/Linkfile`, then run `make link-files`. `make link`, `make unlink`, `dot health`, and `make test-link` all read this file, so one line is all it takes
- **Aliases**: Edit `system/.alias`
- **Functions**: Edit `system/.function`
- **Environment variables**: Edit `system/.env`
- **PATH**: Edit `system/.path`
- **Claude Code settings**: Edit `claude/settings.json`
- **Claude Code skills**: Add to `claude/skills/`
- **Trusted signing keys**: Run `make signers` on a new machine, then commit `config/git/allowed_signers`
- **Ghostty terminal**: Edit `config/ghostty/config` (stowed to `~/.config/ghostty/config`); reload in-app with `Cmd+Shift+,`

## Credits

Many thanks to the [dotfiles community](https://dotfiles.github.io).
