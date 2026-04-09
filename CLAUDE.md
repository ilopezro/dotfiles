# Claude Code Guidelines

## About this repo

Personal macOS dotfiles for managing a consistent development environment across machines. Uses [GNU Stow](https://www.gnu.org/software/stow/) for symlinking configs, a `Makefile` for bootstrapping a fresh machine, and a `dot` CLI for day-to-day maintenance. Designed to be idempotent — `make` is safe to run multiple times.

## Documentation

Whenever new functionality is added, update all relevant documentation points:
- `CLAUDE.md` — add any new key files, stow layout changes, or behavioral guidelines
- `README.md` — update user-facing docs (new commands, targets, tools, install steps)
- `bin/dot` help text — if a new `dot` subcommand is added
- `sub_health` in `bin/dot` — if new symlinks, tools, or runtimes are introduced
- `completions/` — if a new `dot` subcommand is added, update the shell completions

## dot health

Always update the `sub_health` function in `bin/dot` when:
- A new symlink is added or removed via `make link` or `make link-claude`
- A new required tool is added to the setup (brew, stow, asdf, etc.)
- A new asdf runtime is added to `runcom/.tool-versions`

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
- `claude/` — Claude Code settings, statusline, and skills (symlinked individually via `make link-claude`, not stowed)

## Stow layout

- `runcom/` is stowed to `$HOME`
- `config/` is stowed to `$HOME/.config`
- `system/` is sourced directly from `~/dotfiles/system/`, not stowed
