# Claude Code Guidelines

## About this repo

Personal macOS dotfiles for managing a consistent development environment across machines. Uses [GNU Stow](https://www.gnu.org/software/stow/) for symlinking configs, a `Makefile` for bootstrapping a fresh machine, and a `dot` CLI for day-to-day maintenance. Designed to be idempotent — `make` is safe to run multiple times.

## Documentation

Whenever new functionality is added, update all relevant documentation points:
- `CLAUDE.md` — add any new key files, stow layout changes, or behavioral guidelines
- `README.md` — update user-facing docs (new commands, targets, tools, install steps)
- `bin/dot` help text — if a new `dot` subcommand is added
- `install/Linkfile` — if a new individual (non-stowed) symlink is introduced
- `sub_health` in `bin/dot` — if new tools or runtimes are introduced (individual symlinks come from `install/Linkfile`)
- `completions/` — if a new `dot` subcommand is added, update the shell completions

## dot health

Individual symlinks need no `sub_health` change — add a `source|destination` line to `install/Linkfile` and `make link`, `make unlink`, `sub_health`, and `make test-link` all pick it up. Never hardcode an individual symlink path in more than one place; that drift is what `install/Linkfile` exists to prevent.

Cask apps need no `sub_health` change either — add a `cask "name"` line to `install/Caskfile` and `make cask-apps`, `dot install`, and `dot health` all pick it up through `bin/cask-doctor`.

Always update the `sub_health` function in `bin/dot` when:
- A new required tool is added to the setup (brew, stow, asdf, etc.)
- A new asdf runtime is added to `runcom/.tool-versions`
- The commit-signing setup changes (`config/git/allowed_signers`, `make signers`)
- A new Mac App Store app is added to `install/Masfile`
- A new Claude Code plugin is added to `install/Pluginfile`

## README

Always update `README.md` when making changes that affect user-facing behavior, including:
- New or removed `dot` commands
- New or removed Makefile targets
- Changes to the fresh install process
- Changes to post-install manual steps
- New tools or runtimes managed by asdf

## Key files

- `bin/dot` — the `dot` CLI, handles updates, cleaning, and editing
- `bin/cask-doctor` — verifies that every cask in `install/Caskfile` has its App and Binary artifacts on disk, not just a Homebrew receipt. `check` reports and exits non-zero on drift; `repair` reinstalls the broken ones (falling back to a forced uninstall/install) and re-checks. Binary artifacts are matched against their declared target path, which is frequently absolute and outside the Homebrew prefix (`docker-desktop` links into `/usr/local/bin`) — checking only `$(brew --prefix)/bin` made such casks read as broken forever and `make cask-apps` never converge. `repair` primes sudo once on the real terminal before touching any cask and bails out with a hint instead of hanging when there is no terminal to prompt on, clears dangling `/Applications` symlinks itself so Homebrew's sandbox never has to ask for root, and re-derives the broken set on every run so an interrupted repair is fixed by re-running it. Both `make cask-apps` and `dot install` run `repair` after `brew bundle`; `sub_health` runs `check`. Adding a cask to `install/Caskfile` is all that's needed — never hardcode a cask name anywhere else
- `Makefile` — full machine setup, idempotent and safe to re-run. `macos` iterates `MACOS_STEPS` through recursive make rather than listing them as prerequisites, so one failing step still lets the rest run; failures are collected and reported, and the target exits non-zero. Keep new setup steps in `MACOS_STEPS`, not in the prerequisite list, or a failure there will strand everything after it. The `sudo` target primes the credential cache and keeps it warm for the lifetime of the make process (it watches `$$PPID`), because `cask-apps` can need root minutes in and macOS expires the timestamp after 5 minutes. It degrades to a warning when there is no tty instead of failing, so unattended runs still work. Every loop that reads an `install/*file` uses `read -r ... || [ -n "$$var" ]` so a file with no trailing newline does not silently lose its last entry
- `runcom/.zshrc` — zsh config, symlinked to `~/.zshrc` via stow
- `runcom/.tool-versions` — asdf runtime versions, symlinked to `~/.tool-versions` via stow
- `system/` — shell config files sourced by `.zshrc` on every terminal open
- `system/.dotfiles-update` — auto-update check, runs every 13 days
- `install/Brewfile` — Homebrew packages
- `install/Caskfile` — Homebrew cask apps
- `install/Masfile` — Mac App Store apps (`name|id` per line, installed via `mas`, requires the `mas` brew and being signed into the App Store)
- `install/Codefile` — VS Code extensions
- `install/Npmfile` — global npm packages
- `install/Mcpfile` — Claude Code MCP servers (`name|command` per line, registered at user scope via `claude mcp add`)
- `install/Pluginfile` — Claude Code plugins (`plugin@marketplace|source` per line). `make claude-plugins` adds the marketplace then installs the plugin at user scope, skipping either step if already present. Note that plugins can register hooks that run on every session start and prompt submit, so review a plugin's `.claude-plugin/plugin.json` before adding it here.
- `install/Linkfile` — individual symlinks (`source|destination` per line, `$HOME` in the destination is expanded at link time). Single source of truth for every symlink that isn't stow-managed: `make link-files` creates them, `make unlink` removes them, `dot health` verifies them, `make test-link` round-trips the pair. Use it for app-managed directories where stow would conflict with state the app writes itself.
- `claude/` — Claude Code settings, statusline, and skills (symlinked individually via `install/Linkfile`, not stowed)
- `config/ghostty/config` — Ghostty terminal config, stowed to `~/.config/ghostty/config`
- `config/git/allowed_signers` — shared SSH signature-verification allowlist, one `identities key` line per machine. The *signing* key is per-machine and lives in the gitignored `~/.config/git/local`; this file is the union of every machine's public key and is committed. `make signers` appends the current machine's key idempotently.

## Stow layout

- `runcom/` is stowed to `$HOME`
- `config/` is stowed to `$HOME/.config` (e.g. `git`, `ghostty`)
- `system/` is sourced directly from `~/dotfiles/system/`, not stowed
