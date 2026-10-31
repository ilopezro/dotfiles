import { C, STDERR, error, print, section } from "./lib/colors.ts";
import * as casks from "./commands/casks.ts";
import * as defaults from "./commands/defaults.ts";
import { health } from "./commands/health.ts";
import { clean, edit, install, update } from "./commands/setup.ts";

const NAME_WIDTH = 9;
const INDENT = 2 + NAME_WIDTH + 1;

// Wraps at word boundaries within the description column, so continuation lines
// line up under the description instead of folding back to column 0.
function wrap(text: string, width: number) {
  const out: string[] = [];
  let line = "";
  for (const word of text.split(" ")) {
    if (line && line.length + 1 + word.length > width) {
      out.push(line);
      line = word;
    } else {
      line = line ? `${line} ${word}` : word;
    }
  }
  if (line) out.push(line);
  return out;
}

function helpCmd(name: string, description: string) {
  const width = Math.max((process.stdout.columns || 80) - INDENT, 20);
  const [first = "", ...rest] = wrap(description, width);
  print(`  ${C.blue}${name.padEnd(NAME_WIDTH)}${C.reset} ${first}`);
  for (const line of rest) print(`${" ".repeat(INDENT)}${line}`);
}

function help() {
  print(`${C.bold}Usage:${C.reset} dot <command>`);
  print();
  section("Commands:");
  helpCmd("install", "Install packages from Brewfile, Caskfile, Masfile, and Npmfile, login items from Loginfile, macOS defaults from Defaultsfile, MCP servers from Mcpfile, and Claude Code plugins from Pluginfile (initial setup)");
  helpCmd("update", "Update dotfiles (and rebuild dot), Homebrew packages, Oh My Zsh, VS Code extensions, npm tools, and Claude Code plugins");
  helpCmd("health", "Check symlinks, commit signing, required tools, cask apps (and casks not in Caskfile), macOS defaults, login items, Claude Code plugins, and asdf runtimes");
  helpCmd("casks", "check | repair | extras | prune [--all]: verify cask apps are really on disk, reinstall or reclaim broken ones, list or uninstall casks not in Caskfile");
  helpCmd("defaults", "check | apply: report or fix drift from install/Defaultsfile");
  helpCmd("prune", "Uninstall Homebrew casks that are not in Caskfile, asking about each (--all: one prompt for all)");
  helpCmd("clean", "Clean up caches (brew, gem)");
  helpCmd("edit", "Open dotfiles in editor");
  helpCmd("help", "This help message");
}

function usage(text: string): never {
  error(`Usage: ${text}`, STDERR);
  process.exit(2);
}

const exit = (ok: boolean) => process.exit(ok ? 0 : 1);

const [command, sub, ...rest] = process.argv.slice(2);

switch (command) {
  case "install":
    await install();
    break;
  case "update":
    await update();
    break;
  case "health":
    await health();
    break;
  case "casks":
    switch (sub ?? "check") {
      case "check":
        exit(await casks.check());
      case "repair":
        exit(await casks.repair());
      case "extras":
        await casks.reportExtras();
        break;
      case "prune":
        exit(await casks.prune(rest[0] === "--all"));
      default:
        usage("dot casks [check|repair|extras|prune [--all]]");
    }
    break;
  case "defaults":
    switch (sub) {
      case "check":
        exit(await defaults.check());
      case "apply":
        exit(await defaults.apply());
      default:
        usage("dot defaults <check|apply>");
    }
  case "prune":
    exit(await casks.prune(sub === "--all"));
  case "clean":
    await clean();
    break;
  case "edit":
    await edit();
    break;
  default:
    help();
}
