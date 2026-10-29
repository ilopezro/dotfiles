DOTFILES_DIR := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))
STOW_DIR := $(DOTFILES_DIR)
VSCODE_DIR := $(HOME)/Library/Application Support/Code/User
CLAUDE_DIR := $(HOME)/.claude
SIGNERS_FILE := $(DOTFILES_DIR)config/git/allowed_signers
LINKFILE := $(DOTFILES_DIR)install/Linkfile
export PATH := $(DOTFILES_DIR)bin:$(PATH)
# Recipes that print status source the shared helpers so make output matches dot.
COLORS := . $(DOTFILES_DIR)lib/colors.sh;

.PHONY: all macos sudo brew packages brew-packages cask-apps mas-apps oh-my-zsh safe-chain asdf-plugins go-tools npm-tools link stow-runcom stow-config link-vscode link-claude unlink link-files test-link vscode-extensions claude-mcp claude-plugins claude-skills signers login-items macos-defaults demo

all: macos

MACOS_STEPS := packages oh-my-zsh safe-chain link signers asdf-plugins go-tools \
               npm-tools vscode-extensions claude-mcp claude-plugins claude-skills login-items \
               macos-defaults

# Every step below is independently idempotent, so a failing step must not strand the
# ones after it. As plain prerequisites, one broken cask meant `link`, `signers`, and
# the runtimes never ran however many times you re-ran make — the run could never
# reach a fixed point. Run them in order instead, collect failures, and report at the
# end so a re-run still has something left to converge on.
macos: sudo
	@$(COLORS) failed=""; \
	for step in $(MACOS_STEPS); do \
		echo ""; \
		step "$$step"; \
		$(MAKE) --no-print-directory $$step || failed="$$failed $$step"; \
	done; \
	echo ""; \
	if [ -n "$$failed" ]; then \
		error "Finished with failures:$$failed"; \
		note "Each step is safe to re-run: fix the cause, then \`make\` again or \`make <step>\`."; \
		exit 1; \
	fi; \
	success "All steps completed."

# Keep the sudo ticket warm for as long as make runs. `cask-apps` can reach a cask
# that needs root minutes after this target primed the cache, and macOS expires the
# timestamp after 5 minutes — so without the refresher a long run hits a password
# prompt from inside a brew sandbox that has no terminal to show it on. $$PPID is
# make's own pid, so the refresher exits on its own once make is gone.
sudo:
	@$(COLORS) if sudo -n true 2>/dev/null; then \
		note "sudo credentials already cached."; \
	elif [ -t 0 ]; then \
		sudo -v; \
	else \
		warn "No terminal to prompt on, skipping sudo priming."; \
		note "Steps needing root will say so. Run \`sudo -v\` first for an unattended run."; \
	fi
	@pid=$$PPID; while kill -0 $$pid 2>/dev/null; do sudo -n true; sleep 60; done >/dev/null 2>&1 &

brew:
	@$(COLORS) if command -v brew >/dev/null 2>&1; then \
		note "Homebrew already installed."; \
	elif is-macos; then \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
	else \
		note "Not macOS, skipping Homebrew install."; \
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
	@$(COLORS) while IFS='|' read -r name id || [ -n "$$name" ]; do \
		[ -z "$$name" ] && continue; \
		info "Installing $$name..."; \
		mas install "$$id" || true; \
	done < $(DOTFILES_DIR)install/Masfile

safe-chain:
	@$(COLORS) if ! command -v safe-chain >/dev/null 2>&1; then \
		info "Installing safe-chain..."; \
		curl -fsSL https://github.com/AikidoSec/safe-chain/releases/latest/download/install-safe-chain.sh | sh; \
	else \
		note "safe-chain already installed."; \
	fi

ASDF_PLUGINS := nodejs python golang ruby air

asdf-plugins:
	@$(COLORS) installed="$$(asdf plugin list 2>/dev/null)"; \
	for plugin in $(ASDF_PLUGINS); do \
		if printf '%s\n' "$$installed" | grep -qx "$$plugin"; then \
			note "asdf plugin already added: $$plugin"; \
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
	@$(COLORS) while read -r pkg || [ -n "$$pkg" ]; do \
		[ -z "$$pkg" ] && continue; \
		npm install -g "$$pkg"; \
	done < $(DOTFILES_DIR)install/Npmfile
	@asdf reshim nodejs

oh-my-zsh:
	@$(COLORS) if [ ! -d "$(HOME)/.oh-my-zsh" ]; then \
		info "Installing Oh My Zsh..."; \
		sh -c "$$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; \
	else \
		note "Oh My Zsh already installed."; \
	fi
	@$(COLORS) if [ ! -d "$(HOME)/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then \
		info "Installing zsh-autosuggestions..."; \
		git clone https://github.com/zsh-users/zsh-autosuggestions $(HOME)/.oh-my-zsh/custom/plugins/zsh-autosuggestions; \
	else \
		note "zsh-autosuggestions already installed."; \
	fi
	@$(COLORS) if [ ! -d "$(HOME)/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then \
		info "Installing zsh-syntax-highlighting..."; \
		git clone https://github.com/zsh-users/zsh-syntax-highlighting $(HOME)/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting; \
	else \
		note "zsh-syntax-highlighting already installed."; \
	fi

link: stow-runcom stow-config link-vscode link-claude

stow-runcom:
	@$(COLORS) for file in .zshrc .tool-versions .asdfrc; do \
		target="$(HOME)/$$file"; \
		if [ -e "$$target" ] && [ ! -L "$$target" ]; then \
			backup="$$target.bak.$$(date +%Y%m%d%H%M%S)"; \
			warn "Backing up existing $$target to $$backup"; \
			mv "$$target" "$$backup"; \
		fi; \
	done
	stow -d $(STOW_DIR) -t $(HOME) runcom

stow-config:
	mkdir -p $(HOME)/.config
	stow -d $(STOW_DIR) -t $(HOME)/.config config

link-files:
	@$(COLORS) while IFS='|' read -r src dest || [ -n "$$src" ]; do \
		[ -z "$$src" ] && continue; \
		dest=$$(printf '%s' "$$dest" | sed "s|^\$$HOME|$(HOME)|"); \
		mkdir -p "$$(dirname "$$dest")"; \
		if [ -f "$$dest" ] && [ ! -L "$$dest" ]; then \
			backup="$$dest.bak.$$(date +%Y%m%d%H%M%S)"; \
			warn "Backing up existing $$dest to $$backup"; \
			mv "$$dest" "$$backup"; \
		fi; \
		ln -sf "$(DOTFILES_DIR)$$src" "$$dest"; \
	done < $(LINKFILE)

link-vscode link-claude: link-files

signers:
	@$(COLORS) key_path="$$(git config user.signingkey)"; \
	key_path="$${key_path:-$(HOME)/.ssh/id_ed25519.pub}"; \
	case "$$key_path" in "~"*) key_path="$(HOME)$${key_path#\~}";; esac; \
	if [ ! -f "$$key_path" ]; then \
		warn "No public key at $$key_path, skipping allowed_signers."; \
		exit 0; \
	fi; \
	key="$$(awk '{print $$1" "$$2}' "$$key_path")"; \
	if grep -qF "$$key" "$(SIGNERS_FILE)" 2>/dev/null; then \
		note "allowed_signers already trusts this machine's key."; \
	else \
		ids="$$(head -n1 "$(SIGNERS_FILE)" 2>/dev/null | cut -d' ' -f1)"; \
		[ -n "$$ids" ] || ids="$$(git config user.email)"; \
		if [ -s "$(SIGNERS_FILE)" ] && [ -n "$$(tail -c1 "$(SIGNERS_FILE)")" ]; then \
			echo "" >> "$(SIGNERS_FILE)"; \
		fi; \
		echo "$$ids $$key" >> "$(SIGNERS_FILE)"; \
		pass "Added this machine's key to allowed_signers — commit and push it to trust this machine elsewhere."; \
	fi

claude-mcp:
	@$(COLORS) while IFS='|' read -r name cmd || [ -n "$$name" ]; do \
		[ -z "$$name" ] && continue; \
		if claude mcp get "$$name" >/dev/null 2>&1; then \
			note "MCP server already configured: $$name"; \
		else \
			info "Adding MCP server: $$name"; \
			claude mcp add --scope user "$$name" -- $$cmd; \
		fi; \
	done < $(DOTFILES_DIR)install/Mcpfile

claude-plugins:
	@$(COLORS) if ! command -v claude >/dev/null 2>&1; then \
		warn "claude not found, skipping plugins. Rerun \`make claude-plugins\` after Claude Code is installed."; \
		exit 0; \
	fi; \
	while IFS='|' read -r plugin source || [ -n "$$plugin" ]; do \
		[ -z "$$plugin" ] && continue; \
		market="$${plugin#*@}"; \
		if claude plugin marketplace list 2>/dev/null | grep -q "❯ $$market$$"; then \
			note "Marketplace already added: $$market"; \
		else \
			info "Adding marketplace: $$source"; \
			if ! claude plugin marketplace add "$$source"; then \
				warn "Skipping $$plugin: could not reach $$source (needs GitHub access — rerun \`make claude-plugins\` once SSH is set up)."; \
				continue; \
			fi; \
		fi; \
		if claude plugin list 2>/dev/null | grep -q "❯ $$plugin$$"; then \
			note "Plugin already installed: $$plugin"; \
		else \
			info "Installing plugin: $$plugin"; \
			claude plugin install --scope user "$$plugin" || \
				warn "Skipping $$plugin: install failed (rerun \`make claude-plugins\` to retry)."; \
		fi; \
	done < $(DOTFILES_DIR)install/Pluginfile

claude-skills:
	@$(COLORS) if ! command -v npx >/dev/null 2>&1; then \
		warn "npx not found, skipping skills. Rerun \`make claude-skills\` after Node.js is installed."; \
		exit 0; \
	fi; \
	while IFS= read -r source || [ -n "$$source" ]; do \
		[ -z "$$source" ] && continue; \
		if npx --yes skills list -g 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -q "Source: $$source$$"; then \
			note "Skill source already installed: $$source"; \
		else \
			info "Adding skill source: $$source"; \
			npx --yes skills add -g -y "$$source" || \
				warn "Skipping $$source: install failed (rerun \`make claude-skills\` to retry)."; \
		fi; \
	done < $(DOTFILES_DIR)install/Skillfile

# Login items live in the Background Task Management database, which `defaults`
# cannot write — System Events via osascript is the scriptable path. Matched by
# path substring because apps may register a helper inside their own bundle
# (OneDrive's login item is OneDrive.app/Contents/OneDrive Sync Service.app).
# First run prompts once for Automation permission over System Events.
login-items:
	@$(COLORS) if ! is-macos; then note "Not macOS, skipping login items."; exit 0; fi; \
	current="$$(osascript -e 'tell application "System Events" to get the path of every login item' 2>/dev/null)"; \
	while IFS= read -r app || [ -n "$$app" ]; do \
		[ -z "$$app" ] && continue; \
		if [ ! -d "$$app" ]; then \
			warn "Skipping login item (app not installed): $$app"; \
		elif printf '%s' "$$current" | grep -qF "$$app"; then \
			note "Login item already present: $$app"; \
		else \
			info "Adding login item: $$app"; \
			osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"$$app\", hidden:false}" >/dev/null; \
		fi; \
	done < $(DOTFILES_DIR)install/Loginfile

macos-defaults:
	@$(COLORS) if ! is-macos; then note "Not macOS, skipping defaults."; exit 0; fi; \
	macos-defaults apply

unlink:
	stow -d $(STOW_DIR) -t $(HOME) -D runcom
	stow -d $(STOW_DIR) -t $(HOME)/.config -D config
	@$(COLORS) while IFS='|' read -r src dest || [ -n "$$src" ]; do \
		[ -z "$$src" ] && continue; \
		dest=$$(printf '%s' "$$dest" | sed "s|^\$$HOME|$(HOME)|"); \
		rm -f "$$dest"; \
	done < $(LINKFILE)

# Round-trips link/unlink against a throwaway HOME, then asserts nothing in the
# repo is still linked. Catches a Linkfile entry that link or unlink forgot.
test-link:
	@$(COLORS) tmp=$$(mktemp -d) || exit 1; \
	trap 'rm -rf "$$tmp"' EXIT INT TERM; \
	step "Testing link/unlink in $$tmp"; \
	$(MAKE) --no-print-directory HOME="$$tmp" link >/dev/null || exit 1; \
	missing=0; \
	while IFS='|' read -r src dest || [ -n "$$src" ]; do \
		[ -z "$$src" ] && continue; \
		dest=$$(printf '%s' "$$dest" | sed "s|^\$$HOME|$$tmp|"); \
		if [ ! -L "$$dest" ]; then fail "link missing: $$dest"; missing=1; \
		elif [ ! -e "$$dest" ]; then fail "link dangling: $$dest"; missing=1; \
		else pass "linked: $$src"; fi; \
	done < $(LINKFILE); \
	$(MAKE) --no-print-directory HOME="$$tmp" unlink >/dev/null || exit 1; \
	leftover=$$(find "$$tmp" -type l -exec sh -c 'readlink "$$1" | grep -q "^$(DOTFILES_DIR)" && echo "$$1"' _ {} \;); \
	if [ -n "$$leftover" ]; then \
		fail "still linked after unlink:"; \
		echo "$$leftover" | sed 's|^|      |'; \
		missing=1; \
	else \
		pass "teardown removed every link into the repo"; \
	fi; \
	[ "$$missing" = "0" ] || { error "test-link failed."; exit 1; }; \
	success "test-link passed."

vscode-extensions:
	@$(COLORS) while read -r ext || [ -n "$$ext" ]; do \
		[ -z "$$ext" ] && continue; \
		code --install-extension "$$ext" --force 2>/dev/null || true; \
	done < $(DOTFILES_DIR)install/Codefile

# Re-records docs/dot-health.gif. Captures a real run first because the checks are
# too slow, and the login-items check needs permissions, to run inside VHS itself.
demo:
	@$(COLORS) command -v vhs >/dev/null 2>&1 || { error "vhs not found: brew install vhs"; exit 1; }
	CLICOLOR_FORCE=1 $(DOTFILES_DIR)bin/dot health > $(DOTFILES_DIR)docs/.dot-health.ansi
	cd $(DOTFILES_DIR)docs && vhs dot-health.tape
