DOTFILES_DIR := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))
STOW_DIR := $(DOTFILES_DIR)
VSCODE_DIR := $(HOME)/Library/Application Support/Code/User
export PATH := $(DOTFILES_DIR)bin:$(PATH)

.PHONY: all macos sudo brew packages brew-packages cask-apps oh-my-zsh go-tools link unlink vscode-extensions

all: macos

macos: sudo packages oh-my-zsh link go-tools vscode-extensions

sudo:
	sudo -v
	while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

brew:
	is-macos && command -v brew >/dev/null 2>&1 || \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

packages: brew-packages cask-apps

brew-packages: brew
	brew bundle --file=$(DOTFILES_DIR)install/Brewfile

cask-apps: brew
	brew bundle --file=$(DOTFILES_DIR)install/Caskfile

go-tools:
	@asdf plugin list 2>/dev/null | grep -q golang || asdf plugin add golang
	@asdf install golang latest
	@asdf set -u golang latest
	@asdf reshim golang
	go install golang.org/x/tools/gopls@latest
	asdf reshim golang

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

link: stow-runcom stow-config link-vscode

stow-runcom:
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

unlink:
	stow -d $(STOW_DIR) -t $(HOME) -D runcom
	stow -d $(STOW_DIR) -t $(HOME)/.config -D config
	rm -f "$(VSCODE_DIR)/settings.json"

vscode-extensions:
	@cat $(DOTFILES_DIR)install/Codefile | while read ext; do \
		code --install-extension "$$ext" --force 2>/dev/null || true; \
	done
