import { Command } from "commander";
import * as casks from "@/commands/casks.ts";
import * as defaults from "@/commands/defaults.ts";
import { health } from "@/commands/health.ts";
import { clean, edit, install, update } from "@/commands/setup.ts";
import { C, colorEnabled } from "@/lib/colors.ts";

const setExit = (ok: boolean) => {
  process.exitCode = ok ? 0 : 1;
};

// Settings are copied into each subcommand when it is created, so this has to run
// before any .command() call. Color follows colors.ts rather than Commander's own
// detection, which ignores CLICOLOR_FORCE (`make demo` relies on it).
const program = new Command("dot")
  .description("Maintain this machine's dotfiles setup")
  .configureHelp({
    styleTitle: (title) => `${C.bold}${title}${C.reset}`,
    styleCommandText: (text) => `${C.bold}${text}${C.reset}`,
    styleSubcommandText: (text) => `${C.blue}${text}${C.reset}`,
    styleOptionText: (text) => `${C.blue}${text}${C.reset}`,
  })
  .configureOutput({
    getOutHasColors: () => colorEnabled,
    getErrHasColors: () => colorEnabled,
    outputError: (text, write) => write(`${C.red}${text}${C.reset}`),
  })
  .showHelpAfterError();

program
  .command("install")
  .description(
    "Install packages from Brewfile, Caskfile, Masfile, and Npmfile, login items from Loginfile, macOS defaults from Defaultsfile, MCP servers from Mcpfile, and Claude Code plugins from Pluginfile (initial setup)",
  )
  .action(install);

program
  .command("update")
  .description(
    "Update dotfiles (and rebuild dot), Homebrew packages, Oh My Zsh, VS Code extensions, npm tools, and Claude Code plugins",
  )
  .action(update);

program
  .command("health")
  .description(
    "Check symlinks, commit signing, required tools, cask apps (and casks not in Caskfile), macOS defaults, login items, Claude Code plugins, and asdf runtimes",
  )
  .action(health);

const caskCommands = program.command("casks").description("Verify, repair, or prune Homebrew cask apps");
caskCommands
  .command("check")
  .description("Report casks whose App or Binary artifacts are missing, or whose app is not owned by you")
  .action(async () => setExit(await casks.check()));
caskCommands
  .command("repair")
  .description("Reinstall missing or broken casks and reclaim root-owned apps, then re-check")
  .action(async () => setExit(await casks.repair()));
caskCommands.command("extras").description("List installed casks that are not in Caskfile").action(casks.reportExtras);
caskCommands
  .command("prune")
  .description("Uninstall casks that are not in Caskfile, asking about each")
  .option("--all", "Ask once for the whole list")
  .action(async ({ all }: { all?: boolean }) => setExit(await casks.prune(!!all)));

const defaultsCommands = program.command("defaults").description("Check or apply macOS defaults from Defaultsfile");
defaultsCommands
  .command("check")
  .description("Report values that differ from Defaultsfile")
  .action(async () => setExit(await defaults.check()));
defaultsCommands
  .command("apply")
  .description("Write values that differ, then restart the affected apps")
  .action(async () => setExit(await defaults.apply()));

program
  .command("prune")
  .description("Uninstall Homebrew casks that are not in Caskfile, asking about each (same as `dot casks prune`)")
  .option("--all", "Ask once for the whole list")
  .action(async ({ all }: { all?: boolean }) => setExit(await casks.prune(!!all)));

program.command("clean").description("Clean up caches (brew, gem)").action(clean);
program.command("edit").description("Open dotfiles in editor").action(edit);

// Commander treats a bare `dot` or `dot casks` as an error (help on stderr, exit 1).
// Asking for the menu is not a mistake, so show it normally.
const args = process.argv.slice(2);
const menu = args.length === 0 ? program : program.commands.find((c) => c.name() === args[0] && c.commands.length);
if (args.length <= 1 && menu) menu.help();

await program.parseAsync();
