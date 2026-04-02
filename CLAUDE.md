# Claude Code Guidelines

## About this repo

Personal macOS dotfiles for managing a consistent development environment across machines. Uses [GNU Stow](https://www.gnu.org/software/stow/) for symlinking configs, a `Makefile` for bootstrapping a fresh machine, and a `dot` CLI for day-to-day maintenance. Designed to be idempotent — `make` is safe to run multiple times.

## README

Always update `README.md` when making changes that affect user-facing behavior, including:
- New or removed `dot` commands
- New or removed Makefile targets
- Changes to the fresh install process
- Changes to post-install manual steps
- New tools or runtimes managed by asdf

## Key files

- `bin/dot` — the `dot` CLI, handles updates, cleaning, and editing
- `Makefile` — full machine setup, idempotent and safe to re-run
- `runcom/.zshrc` — zsh config, symlinked to `~/.zshrc` via stow
- `runcom/.tool-versions` — asdf runtime versions, symlinked to `~/.tool-versions` via stow
- `system/` — shell config files sourced by `.zshrc` on every terminal open
- `system/.dotfiles-update` — auto-update check, runs every 13 days
- `install/Brewfile` — Homebrew packages
- `install/Caskfile` — Homebrew cask apps
- `install/Codefile` — VS Code extensions

## Stow layout

- `runcom/` is stowed to `$HOME`
- `config/` is stowed to `$HOME/.config`
- `system/` is sourced directly from `~/dotfiles/system/`, not stowed
