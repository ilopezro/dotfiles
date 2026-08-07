DOTFILES_DIR := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))
STOW_DIR := $(DOTFILES_DIR)
VSCODE_DIR := $(HOME)/Library/Application Support/Code/User
CLAUDE_DIR := $(HOME)/.claude
SIGNERS_FILE := $(DOTFILES_DIR)config/git/allowed_signers
export PATH := $(DOTFILES_DIR)bin:$(PATH)

.PHONY: all macos sudo brew packages brew-packages cask-apps mas-apps oh-my-zsh safe-chain asdf-plugins go-tools npm-tools link unlink vscode-extensions claude-mcp signers

all: macos

macos: sudo packages oh-my-zsh safe-chain link signers asdf-plugins go-tools npm-tools vscode-extensions claude-mcp

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

link-vscode:
	@mkdir -p "$(VSCODE_DIR)"
	@if [ -f "$(VSCODE_DIR)/settings.json" ] && [ ! -L "$(VSCODE_DIR)/settings.json" ]; then \
		echo "Backing up existing VS Code settings to settings.json.bak"; \
		mv "$(VSCODE_DIR)/settings.json" "$(VSCODE_DIR)/settings.json.bak"; \
	fi
	ln -sf $(DOTFILES_DIR)vscode/settings.json "$(VSCODE_DIR)/settings.json"

link-claude:
	@mkdir -p "$(CLAUDE_DIR)/skills/commit"
	@if [ -f "$(CLAUDE_DIR)/settings.json" ] && [ ! -L "$(CLAUDE_DIR)/settings.json" ]; then \
		echo "Backing up existing Claude settings to settings.json.bak"; \
		mv "$(CLAUDE_DIR)/settings.json" "$(CLAUDE_DIR)/settings.json.bak"; \
	fi
	ln -sf $(DOTFILES_DIR)claude/settings.json "$(CLAUDE_DIR)/settings.json"
	ln -sf $(DOTFILES_DIR)claude/statusline_command.sh "$(CLAUDE_DIR)/statusline_command.sh"
	ln -sf $(DOTFILES_DIR)claude/skills/commit/SKILL.md "$(CLAUDE_DIR)/skills/commit/SKILL.md"
	ln -sf $(DOTFILES_DIR)claude/CLAUDE.md "$(CLAUDE_DIR)/CLAUDE.md"

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

unlink:
	stow -d $(STOW_DIR) -t $(HOME) -D runcom
	stow -d $(STOW_DIR) -t $(HOME)/.config -D config
	rm -f "$(VSCODE_DIR)/settings.json"
	rm -f "$(CLAUDE_DIR)/settings.json"
	rm -f "$(CLAUDE_DIR)/statusline_command.sh"
	rm -f "$(CLAUDE_DIR)/skills/commit/SKILL.md"

vscode-extensions:
	@cat $(DOTFILES_DIR)install/Codefile | while read ext; do \
		code --install-extension "$$ext" --force 2>/dev/null || true; \
	done
