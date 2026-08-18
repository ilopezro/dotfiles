DOTFILES_DIR := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))
STOW_DIR := $(DOTFILES_DIR)
VSCODE_DIR := $(HOME)/Library/Application Support/Code/User
CLAUDE_DIR := $(HOME)/.claude
SIGNERS_FILE := $(DOTFILES_DIR)config/git/allowed_signers
LINKFILE := $(DOTFILES_DIR)install/Linkfile
export PATH := $(DOTFILES_DIR)bin:$(PATH)

.PHONY: all macos sudo brew packages brew-packages cask-apps mas-apps oh-my-zsh safe-chain asdf-plugins go-tools npm-tools link unlink link-files test-link vscode-extensions claude-mcp claude-plugins signers

all: macos

macos: sudo packages oh-my-zsh safe-chain link signers asdf-plugins go-tools npm-tools vscode-extensions claude-mcp claude-plugins

sudo:
	sudo -v
	while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

brew:
	is-macos && command -v brew >/dev/null 2>&1 || \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

packages: brew-packages cask-apps mas-apps

brew-packages: brew
	brew bundle --file=$(DOTFILES_DIR)install/Brewfile

cask-apps: brew
	brew bundle --file=$(DOTFILES_DIR)install/Caskfile

mas-apps: brew-packages
	@while IFS='|' read -r name id; do \
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

asdf-plugins:
	@asdf plugin list 2>/dev/null | grep -q nodejs  || asdf plugin add nodejs
	@asdf plugin list 2>/dev/null | grep -q python  || asdf plugin add python
	@asdf plugin list 2>/dev/null | grep -q golang  || asdf plugin add golang
	@asdf plugin list 2>/dev/null | grep -q ruby    || asdf plugin add ruby
	@asdf plugin list 2>/dev/null | grep -q air     || asdf plugin add air
	@asdf install
	@asdf reshim

go-tools:
	go install golang.org/x/tools/gopls@latest
	@asdf reshim golang

npm-tools:
	@cat $(DOTFILES_DIR)install/Npmfile | while read pkg; do \
		[ -z "$$pkg" ] && continue; \
		npm install -g "$$pkg"; \
	done
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
	@while IFS='|' read -r src dest; do \
		[ -z "$$src" ] && continue; \
		dest=$$(printf '%s' "$$dest" | sed "s|^\$$HOME|$(HOME)|"); \
		mkdir -p "$$(dirname "$$dest")"; \
		if [ -f "$$dest" ] && [ ! -L "$$dest" ]; then \
			echo "Backing up existing $$dest to $$dest.bak"; \
			mv "$$dest" "$$dest.bak"; \
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
	@while IFS='|' read -r name cmd; do \
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
	while IFS='|' read -r plugin source; do \
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

unlink:
	stow -d $(STOW_DIR) -t $(HOME) -D runcom
	stow -d $(STOW_DIR) -t $(HOME)/.config -D config
	@while IFS='|' read -r src dest; do \
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
	while IFS='|' read -r src dest; do \
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
	@cat $(DOTFILES_DIR)install/Codefile | while read ext; do \
		code --install-extension "$$ext" --force 2>/dev/null || true; \
	done
