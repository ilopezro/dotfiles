// install, update, clean, and edit: the commands that change the machine.

import * as casks from "@/commands/casks.ts";
import * as defaults from "@/commands/defaults.ts";
import { info, note, step, success, warn } from "@/lib/colors.ts";
import { readFields, readLines } from "@/lib/manifest.ts";
import { DOTFILES_DIR, HOME, installFile } from "@/lib/paths.ts";
import { capture, has, lines, make, run, succeeds } from "@/lib/proc.ts";

async function installPlugins() {
  for (const [plugin = "", source = ""] of readFields(installFile("Pluginfile"))) {
    const market = plugin.slice(plugin.indexOf("@") + 1);
    const markets = lines((await capture(["claude", "plugin", "marketplace", "list"])).out);
    if (markets.some((line) => line.endsWith(`❯ ${market}`))) {
      note(`Marketplace already added: ${market}`);
    } else {
      info(`Adding marketplace: ${source}`);
      if (!(await run(["claude", "plugin", "marketplace", "add", source]))) {
        warn(`Skipping ${plugin}: could not reach ${source} (needs GitHub access).`);
        continue;
      }
    }
    const installed = lines((await capture(["claude", "plugin", "list"])).out);
    if (installed.some((line) => line.endsWith(`❯ ${plugin}`))) {
      note(`Plugin already installed: ${plugin}`);
    } else {
      info(`Installing plugin: ${plugin}`);
      if (!(await run(["claude", "plugin", "install", "--scope", "user", plugin]))) {
        warn(`Skipping ${plugin}: install failed.`);
      }
    }
  }
}

export async function install() {
  step("Installing Homebrew packages...");
  await run(["brew", "bundle", `--file=${installFile("Brewfile")}`]);

  step("Installing cask apps...");
  await run(["brew", "bundle", `--file=${installFile("Caskfile")}`]);
  await casks.repair();

  step("Installing Mac App Store apps...");
  for (const [name = "", id = ""] of readFields(installFile("Masfile"))) {
    info(`Installing ${name}...`);
    await run(["mas", "install", id]);
  }

  step("Installing global npm tools...");
  for (const pkg of readLines(installFile("Npmfile"))) {
    await run(["npm", "install", "-g", pkg]);
  }

  step("Configuring Claude Code MCP servers...");
  for (const [name = "", cmd = ""] of readFields(installFile("Mcpfile"))) {
    if (await succeeds(["claude", "mcp", "get", name])) {
      note(`MCP server already configured: ${name}`);
    } else {
      info(`Adding MCP server: ${name}`);
      await run(["claude", "mcp", "add", "--scope", "user", name, "--", ...cmd.trim().split(/\s+/)]);
    }
  }

  step("Registering login items...");
  await make("login-items");

  step("Applying macOS defaults...");
  await defaults.apply();

  if (!has("claude")) {
    warn("Skipping Claude Code plugins: claude not found.");
  } else {
    step("Installing Claude Code plugins...");
    await installPlugins();
  }
}

export async function update() {
  step("[1/6] Updating dotfiles...");
  const clean =
    (await succeeds(["git", "-C", DOTFILES_DIR, "diff", "--quiet"])) &&
    (await succeeds(["git", "-C", DOTFILES_DIR, "diff", "--cached", "--quiet"]));
  if (clean) {
    await run(["git", "-C", DOTFILES_DIR, "pull"]);
    // Rebuilds only when src/ changed. The rest of this run still uses the binary
    // already in memory; the new one takes effect on the next `dot` call.
    await make("dot-bin");
  } else {
    warn(`Skipping: you have local changes in ${DOTFILES_DIR}`);
  }

  step("[2/6] Updating Homebrew...");
  // Self-updating casks (Slack) leave their app root-owned, so upgrading them needs
  // sudo. Without a cached credential brew's prompt fails mid-upgrade and strands a
  // backup in the Caskroom that breaks every later upgrade of that cask.
  if (!(await succeeds(["sudo", "-n", "true"])) && process.stdin.isTTY) {
    await run(["sudo", "-v"]);
  }
  setInterval(() => void succeeds(["sudo", "-n", "true"]), 60_000).unref();
  await run(["brew", "update"]);
  // Reclaim root-owned apps and restore missing artifacts first, or the upgrade
  // trips over them.
  await casks.repair();
  await run(["brew", "upgrade"]);

  step("[3/6] Updating Oh My Zsh...");
  await run([`${process.env.ZSH ?? `${HOME}/.oh-my-zsh`}/tools/upgrade.sh`]);

  step("[4/6] Updating VS Code extensions...");
  for (const ext of readLines(installFile("Codefile"))) {
    await run(["code", "--install-extension", ext, "--force"], { quietErrors: true });
  }

  step("[5/6] Updating global npm tools...");
  for (const pkg of readLines(installFile("Npmfile"))) {
    await run(["npm", "install", "-g", pkg]);
  }

  step("[6/6] Updating Claude Code plugins...");
  for (const [plugin = ""] of readFields(installFile("Pluginfile"))) {
    await run(["claude", "plugin", "update", plugin], { quietErrors: true });
  }

  success("Done!");
}

export async function clean() {
  step("Cleaning Homebrew cache...");
  await run(["brew", "cleanup"]);

  step("Cleaning gem cache...");
  await run(["gem", "cleanup"], { quietErrors: true });
}

export async function edit() {
  await run(["code", DOTFILES_DIR]);
}
