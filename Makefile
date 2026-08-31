DOTFILES_DIR := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))
STOW_DIR := $(DOTFILES_DIR)
VSCODE_DIR := $(HOME)/Library/Application Support/Code/User
CLAUDE_DIR := $(HOME)/.claude
SIGNERS_FILE := $(DOTFILES_DIR)config/git/allowed_signers
LINKFILE := $(DOTFILES_DIR)install/Linkfile
export PATH := $(DOTFILES_DIR)bin:$(PATH)

.PHONY: all macos sudo brew packages brew-packages cask-apps mas-apps oh-my-zsh safe-chain asdf-plugins go-tools npm-tools link stow-runcom stow-config link-vscode link-claude unlink link-files test-link vscode-extensions claude-mcp claude-plugins signers login-items macos-defaults

all: macos

MACOS_STEPS := packages oh-my-zsh safe-chain link signers asdf-plugins go-tools \
               npm-tools vscode-extensions claude-mcp claude-plugins login-items \
               macos-defaults

# Every step below is independently idempotent, so a failing step must not strand the
# ones after it. As plain prerequisites, one broken cask meant `link`, `signers`, and
# the runtimes never ran however many times you re-ran make — the run could never
# reach a fixed point. Run them in order instead, collect failures, and report at the
# end so a re-run still has something left to converge on.
macos: sudo
	@failed=""; \
	for step in $(MACOS_STEPS); do \
		echo ""; \
		echo "==> $$step"; \
		$(MAKE) --no-print-directory $$step || failed="$$failed $$step"; \
	done; \
	echo ""; \
	if [ -n "$$failed" ]; then \
		echo "Finished with failures:$$failed"; \
		echo "Each step is safe to re-run: fix the cause, then \`make\` again or \`make <step>\`."; \
		exit 1; \
	fi; \
	echo "All steps completed."

# Keep the sudo ticket warm for as long as make runs. `cask-apps` can reach a cask
# that needs root minutes after this target primed the cache, and macOS expires the
# timestamp after 5 minutes — so without the refresher a long run hits a password
# prompt from inside a brew sandbox that has no terminal to show it on. $$PPID is
# make's own pid, so the refresher exits on its own once make is gone.
sudo:
	@if sudo -n true 2>/dev/null; then \
		echo "sudo credentials already cached."; \
	elif [ -t 0 ]; then \
		sudo -v; \
	else \
		echo "No terminal to prompt on, skipping sudo priming."; \
		echo "  Steps needing root will say so. Run \`sudo -v\` first for an unattended run."; \
	fi
	@pid=$$PPID; while kill -0 $$pid 2>/dev/null; do sudo -n true; sleep 60; done >/dev/null 2>&1 &

brew:
	@if command -v brew >/dev/null 2>&1; then \
		echo "Homebrew already installed."; \
	elif is-macos; then \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
	else \
		echo "Not macOS, skipping Homebrew install."; \
	fi

packages: brew-packages cask-apps mas-apps

brew-packages: brew
	brew bundle --file=$(DOTFILES_DIR)install/Brewfile

# `brew bundle` trusts its own receipts, so a cask whose app was deleted by a failed
# upgrade still reports as installed. Let bundle do the bulk work, then let
# cask-doctor find and reinstall anything whose artifacts are actually missing.
cask-apps: brew sudo
	brew bundle --file=$(DOTFILES_DIR)install/Caskfile || true
	cask-doctor repair

mas-apps: brew-packages
	@while IFS='|' read -r name id || [ -n "$$name" ]; do \
		[ -z "$$name" ] && continue; \
		echo "Installing $$name..."; \
		mas install "$$id" || true; \
	done < $(DOTFILES_DIR)install/Masfile

safe-chain:
	@if ! command -v safe-chain >/dev/null 2>&1; then \
		echo "Installing safe-chain..."; \
		curl -fsSL https://github.com/AikidoSec/safe-chain/releases/latest/download/install-safe-chain.sh | sh; \
	else \
		echo "safe-chain already installed."; \
	fi

ASDF_PLUGINS := nodejs python golang ruby air

asdf-plugins:
	@installed="$$(asdf plugin list 2>/dev/null)"; \
	for plugin in $(ASDF_PLUGINS); do \
		if printf '%s\n' "$$installed" | grep -qx "$$plugin"; then \
			echo "asdf plugin already added: $$plugin"; \
		else \
			asdf plugin add "$$plugin"; \
		fi; \
	done
	@asdf install
	@asdf reshim

go-tools:
	go install golang.org/x/tools/gopls@latest
	@asdf reshim golang

npm-tools:
	@while read -r pkg || [ -n "$$pkg" ]; do \
		[ -z "$$pkg" ] && continue; \
		npm install -g "$$pkg"; \
	done < $(DOTFILES_DIR)install/Npmfile
	@asdf reshim nodejs

oh-my-zsh:
	@if [ ! -d "$(HOME)/.oh-my-zsh" ]; then \
		echo "Installing Oh My Zsh..."; \
		sh -c "$$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; \
	else \
		echo "Oh My Zsh already installed."; \
	fi
	@if [ ! -d "$(HOME)/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then \
		echo "Installing zsh-autosuggestions..."; \
		git clone https://github.com/zsh-users/zsh-autosuggestions $(HOME)/.oh-my-zsh/custom/plugins/zsh-autosuggestions; \
	else \
		echo "zsh-autosuggestions already installed."; \
	fi
	@if [ ! -d "$(HOME)/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then \
		echo "Installing zsh-syntax-highlighting..."; \
		git clone https://github.com/zsh-users/zsh-syntax-highlighting $(HOME)/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting; \
	else \
		echo "zsh-syntax-highlighting already installed."; \
	fi

link: stow-runcom stow-config link-vscode link-claude

stow-runcom:
	@for file in .zshrc .tool-versions .asdfrc; do \
		target="$(HOME)/$$file"; \
		if [ -e "$$target" ] && [ ! -L "$$target" ]; then \
			backup="$$target.bak.$$(date +%Y%m%d%H%M%S)"; \
			echo "Backing up existing $$target to $$backup"; \
			mv "$$target" "$$backup"; \
		fi; \
	done
	stow -d $(STOW_DIR) -t $(HOME) runcom

stow-config:
	mkdir -p $(HOME)/.config
	stow -d $(STOW_DIR) -t $(HOME)/.config config

link-files:
	@while IFS='|' read -r src dest || [ -n "$$src" ]; do \
		[ -z "$$src" ] && continue; \
		dest=$$(printf '%s' "$$dest" | sed "s|^\$$HOME|$(HOME)|"); \
		mkdir -p "$$(dirname "$$dest")"; \
		if [ -f "$$dest" ] && [ ! -L "$$dest" ]; then \
			backup="$$dest.bak.$$(date +%Y%m%d%H%M%S)"; \
			echo "Backing up existing $$dest to $$backup"; \
			mv "$$dest" "$$backup"; \
		fi; \
		ln -sf "$(DOTFILES_DIR)$$src" "$$dest"; \
	done < $(LINKFILE)

link-vscode link-claude: link-files

signers:
	@key_path="$$(git config user.signingkey)"; \
	key_path="$${key_path:-$(HOME)/.ssh/id_ed25519.pub}"; \
	case "$$key_path" in "~"*) key_path="$(HOME)$${key_path#\~}";; esac; \
	if [ ! -f "$$key_path" ]; then \
		echo "No public key at $$key_path, skipping allowed_signers."; \
		exit 0; \
	fi; \
	key="$$(awk '{print $$1" "$$2}' "$$key_path")"; \
	if grep -qF "$$key" "$(SIGNERS_FILE)" 2>/dev/null; then \
		echo "allowed_signers already trusts this machine's key."; \
	else \
		ids="$$(head -n1 "$(SIGNERS_FILE)" 2>/dev/null | cut -d' ' -f1)"; \
		[ -n "$$ids" ] || ids="$$(git config user.email)"; \
		if [ -s "$(SIGNERS_FILE)" ] && [ -n "$$(tail -c1 "$(SIGNERS_FILE)")" ]; then \
			echo "" >> "$(SIGNERS_FILE)"; \
		fi; \
		echo "$$ids $$key" >> "$(SIGNERS_FILE)"; \
		echo "Added this machine's key to allowed_signers — commit and push it to trust this machine elsewhere."; \
	fi

claude-mcp:
	@while IFS='|' read -r name cmd || [ -n "$$name" ]; do \
		[ -z "$$name" ] && continue; \
		if claude mcp get "$$name" >/dev/null 2>&1; then \
			echo "MCP server already configured: $$name"; \
		else \
			echo "Adding MCP server: $$name"; \
			claude mcp add --scope user "$$name" -- $$cmd; \
		fi; \
	done < $(DOTFILES_DIR)install/Mcpfile

claude-plugins:
	@if ! command -v claude >/dev/null 2>&1; then \
		echo "claude not found, skipping plugins. Rerun \`make claude-plugins\` after Claude Code is installed."; \
		exit 0; \
	fi; \
	while IFS='|' read -r plugin source || [ -n "$$plugin" ]; do \
		[ -z "$$plugin" ] && continue; \
		market="$${plugin#*@}"; \
		if claude plugin marketplace list 2>/dev/null | grep -q "❯ $$market$$"; then \
			echo "Marketplace already added: $$market"; \
		else \
			echo "Adding marketplace: $$source"; \
			if ! claude plugin marketplace add "$$source"; then \
				echo "  Skipping $$plugin: could not reach $$source (needs GitHub access — rerun \`make claude-plugins\` once SSH is set up)."; \
				continue; \
			fi; \
		fi; \
		if claude plugin list 2>/dev/null | grep -q "❯ $$plugin$$"; then \
			echo "Plugin already installed: $$plugin"; \
		else \
			echo "Installing plugin: $$plugin"; \
			claude plugin install --scope user "$$plugin" || \
				echo "  Skipping $$plugin: install failed (rerun \`make claude-plugins\` to retry)."; \
		fi; \
	done < $(DOTFILES_DIR)install/Pluginfile

# Login items live in the Background Task Management database, which `defaults`
# cannot write — System Events via osascript is the scriptable path. Matched by
# path substring because apps may register a helper inside their own bundle
# (OneDrive's login item is OneDrive.app/Contents/OneDrive Sync Service.app).
# First run prompts once for Automation permission over System Events.
login-items:
	@if ! is-macos; then echo "Not macOS, skipping login items."; exit 0; fi; \
	current="$$(osascript -e 'tell application "System Events" to get the path of every login item' 2>/dev/null)"; \
	while IFS= read -r app || [ -n "$$app" ]; do \
		[ -z "$$app" ] && continue; \
		if [ ! -d "$$app" ]; then \
			echo "Skipping login item (app not installed): $$app"; \
		elif printf '%s' "$$current" | grep -qF "$$app"; then \
			echo "Login item already present: $$app"; \
		else \
			echo "Adding login item: $$app"; \
			osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"$$app\", hidden:false}" >/dev/null; \
		fi; \
	done < $(DOTFILES_DIR)install/Loginfile

macos-defaults:
	@if ! is-macos; then echo "Not macOS, skipping defaults."; exit 0; fi; \
	macos-defaults apply

unlink:
	stow -d $(STOW_DIR) -t $(HOME) -D runcom
	stow -d $(STOW_DIR) -t $(HOME)/.config -D config
	@while IFS='|' read -r src dest || [ -n "$$src" ]; do \
		[ -z "$$src" ] && continue; \
		dest=$$(printf '%s' "$$dest" | sed "s|^\$$HOME|$(HOME)|"); \
		rm -f "$$dest"; \
	done < $(LINKFILE)

# Round-trips link/unlink against a throwaway HOME, then asserts nothing in the
# repo is still linked. Catches a Linkfile entry that link or unlink forgot.
test-link:
	@tmp=$$(mktemp -d) || exit 1; \
	trap 'rm -rf "$$tmp"' EXIT INT TERM; \
	echo "Testing link/unlink in $$tmp"; \
	$(MAKE) --no-print-directory HOME="$$tmp" link >/dev/null || exit 1; \
	missing=0; \
	while IFS='|' read -r src dest || [ -n "$$src" ]; do \
		[ -z "$$src" ] && continue; \
		dest=$$(printf '%s' "$$dest" | sed "s|^\$$HOME|$$tmp|"); \
		if [ ! -L "$$dest" ]; then echo "  ✗ link missing: $$dest"; missing=1; \
		elif [ ! -e "$$dest" ]; then echo "  ✗ link dangling: $$dest"; missing=1; \
		else echo "  ✓ linked: $$src"; fi; \
	done < $(LINKFILE); \
	$(MAKE) --no-print-directory HOME="$$tmp" unlink >/dev/null || exit 1; \
	leftover=$$(find "$$tmp" -type l -exec sh -c 'readlink "$$1" | grep -q "^$(DOTFILES_DIR)" && echo "$$1"' _ {} \;); \
	if [ -n "$$leftover" ]; then \
		echo "  ✗ still linked after unlink:"; \
		echo "$$leftover" | sed 's|^|      |'; \
		missing=1; \
	else \
		echo "  ✓ teardown removed every link into the repo"; \
	fi; \
	[ "$$missing" = "0" ] || { echo "test-link failed."; exit 1; }; \
	echo "test-link passed."

vscode-extensions:
	@while read -r ext || [ -n "$$ext" ]; do \
		[ -z "$$ext" ] && continue; \
		code --install-extension "$$ext" --force 2>/dev/null || true; \
	done < $(DOTFILES_DIR)install/Codefile
