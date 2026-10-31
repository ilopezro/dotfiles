import { C, STDERR, STDOUT, error, print, section } from "@/lib/colors.ts";
import * as casks from "@/commands/casks.ts";
import * as defaults from "@/commands/defaults.ts";
import { health } from "@/commands/health.ts";
import { clean, edit, install, update } from "@/commands/setup.ts";

type Row = [name: string, description: string];

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

function helpPage(usage: string, heading: string, rows: Row[], footer?: string, fd = STDOUT) {
  const columns = (fd === STDERR ? process.stderr.columns : process.stdout.columns) || 80;
  const width = Math.max(columns - INDENT, 20);
  print(`${C.bold}Usage:${C.reset} ${usage}`, fd);
  print("", fd);
  section(heading, fd);
  for (const [name, description] of rows) {
    const [first = "", ...rest] = wrap(description, width);
    print(`  ${C.blue}${name.padEnd(NAME_WIDTH)}${C.reset} ${first}`, fd);
    for (const line of rest) print(`${" ".repeat(INDENT)}${line}`, fd);
  }
  if (footer) {
    print("", fd);
    print(`${C.dim}${footer}${C.reset}`, fd);
  }
}

const COMMANDS: Row[] = [
  ["install", "Install packages from Brewfile, Caskfile, Masfile, and Npmfile, login items from Loginfile, macOS defaults from Defaultsfile, MCP servers from Mcpfile, and Claude Code plugins from Pluginfile (initial setup)"],
  ["update", "Update dotfiles (and rebuild dot), Homebrew packages, Oh My Zsh, VS Code extensions, npm tools, and Claude Code plugins"],
  ["health", "Check symlinks, commit signing, required tools, cask apps (and casks not in Caskfile), macOS defaults, login items, Claude Code plugins, and asdf runtimes"],
  ["casks", "Verify, repair, or prune Homebrew cask apps"],
  ["defaults", "Check or apply macOS defaults from Defaultsfile"],
  ["prune", "Uninstall Homebrew casks that are not in Caskfile, asking about each (--all: one prompt for all)"],
  ["clean", "Clean up caches (brew, gem)"],
  ["edit", "Open dotfiles in editor"],
  ["help", "This help message"],
];

const SUBCOMMANDS = {
  casks: {
    usage: "dot casks <command>",
    rows: [
      ["check", "Report casks whose App or Binary artifacts are missing, or whose app is not owned by you"],
      ["repair", "Reinstall missing or broken casks and reclaim root-owned apps, then re-check"],
      ["extras", "List installed casks that are not in Caskfile"],
      ["prune", "Uninstall casks that are not in Caskfile, asking about each (--all: one prompt for all)"],
      ["help", "This help message"],
    ] as Row[],
  },
  defaults: {
    usage: "dot defaults <command>",
    rows: [
      ["check", "Report values that differ from Defaultsfile"],
      ["apply", "Write values that differ, then restart the affected apps"],
      ["help", "This help message"],
    ] as Row[],
  },
};

const help = () => helpPage("dot <command>", "Commands:", COMMANDS, "Run `dot <command> help` for a command's subcommands.");

// No subcommand, or `help`, is a request for help; anything else unknown is a usage error.
function subHelp(command: keyof typeof SUBCOMMANDS, sub: string | undefined): never {
  const { usage, rows } = SUBCOMMANDS[command];
  const asked = sub === undefined || ["help", "-h", "--help"].includes(sub);
  if (!asked) {
    error(`dot ${command}: unknown command '${sub}'`, STDERR);
    print("", STDERR);
  }
  helpPage(usage, "Commands:", rows, undefined, asked ? STDOUT : STDERR);
  process.exit(asked ? 0 : 2);
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
    switch (sub) {
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
        subHelp("casks", sub);
    }
    break;
  case "defaults":
    switch (sub) {
      case "check":
        exit(await defaults.check());
      case "apply":
        exit(await defaults.apply());
      default:
        subHelp("defaults", sub);
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
