import { existsSync, lstatSync, statSync } from "node:fs";
import { basename, join } from "node:path";
import * as casks from "@/commands/casks.ts";
import * as defaults from "@/commands/defaults.ts";
import { error, fail, info, note, pass, print, section, step, success } from "@/lib/colors.ts";
import { parseToolVersions, readFields, readLines, readText } from "@/lib/manifest.ts";
import { DOTFILES_DIR, expandHome, HOME, installFile } from "@/lib/paths.ts";
import { capture, has, lines, make, run, succeeds } from "@/lib/proc.ts";
import { spin } from "@/lib/spinner.ts";

const isLink = (path: string) => {
  try {
    return lstatSync(path).isSymbolicLink();
  } catch {
    return false;
  }
};

const isDir = (path: string) => {
  try {
    return statSync(path).isDirectory();
  } catch {
    return false;
  }
};

type Fix = { command: string; apply: () => Promise<boolean> };

// Printed with -C so the command can be pasted from any directory.
const makeFix = (target: string): Fix => ({
  command: `make -C ${DOTFILES_DIR.replace(HOME, "~")} ${target}`,
  apply: () => make(target),
});
const CASKS_FIX: Fix = { command: "dot casks repair", apply: casks.repair };
const DEFAULTS_FIX: Fix = { command: "dot defaults apply", apply: defaults.apply };

// Installed by a Brewfile or Caskfile entry, except git, which comes with the Xcode Command Line Tools.
const TOOL_FIXES: Record<string, Fix> = {
  brew: makeFix("brew"),
  git: { command: "xcode-select --install", apply: () => run(["xcode-select", "--install"]) },
  code: makeFix("cask-apps"),
};

export async function health({ fix = false } = {}): Promise<boolean> {
  // Every failure names its fix; keyed by command so the summary lists each once.
  const fixes = new Map<string, Fix>();
  const failed = (fix: Fix) => fixes.set(fix.command, fix);
  const check = (label: string, result: true | string, fix: Fix) => {
    if (result === true) {
      pass(label);
    } else {
      fail(`${label} (${result})`);
      failed(fix);
    }
  };
  // For checks that wait on a command: the spinner holds the line until the result replaces it.
  const probe = async (label: string, result: () => Promise<true | string>, fix: Fix) =>
    check(label, await spin(label, result), fix);

  section("Symlinks");
  for (const file of [".zshrc", ".tool-versions", ".asdfrc"]) {
    check(file, isLink(join(HOME, file)) || "not linked", makeFix("stow-runcom"));
  }
  for (const [src = "", dest = ""] of readFields(installFile("Linkfile"))) {
    const target = expandHome(dest);
    check(src, !isLink(target) ? "not linked" : !existsSync(target) ? "dangling link" : true, makeFix("link-files"));
  }

  print();
  section("Commits");
  const keyPath = expandHome(
    (await capture(["git", "config", "user.signingkey"])).out || `${HOME}/.ssh/id_ed25519.pub`,
  );
  if (!existsSync(keyPath)) {
    check("signing key", `no key at ${keyPath}`, makeFix("signers"));
  } else {
    const key = (readLines(keyPath)[0] ?? "").split(/\s+/).slice(0, 2).join(" ");
    const signers = readText(join(DOTFILES_DIR, "config/git/allowed_signers"));
    check("key trusted in allowed_signers", signers.includes(key) || "key not listed", makeFix("signers"));
  }
  const hooksPath = (await capture(["git", "-C", DOTFILES_DIR, "config", "core.hooksPath"])).out;
  check("pre-commit hook enabled", hooksPath === ".githooks" || "core.hooksPath not set", makeFix("git-hooks"));

  print();
  section("Tools");
  for (const cmd of ["brew", "git", "stow", "asdf", "bun", "code", "mas"]) {
    check(cmd, has(cmd) || "not found", TOOL_FIXES[cmd] ?? makeFix("brew-packages"));
  }

  print();
  section("Cask apps");
  if (!(await casks.check())) failed(CASKS_FIX);
  await casks.reportExtras();

  print();
  section("Global npm tools");
  for (const pkg of readLines(installFile("Npmfile"))) {
    await probe(
      pkg,
      async () => (await succeeds(["npm", "list", "-g", "--depth=0", pkg])) || "not installed",
      makeFix("npm-tools"),
    );
  }

  print();
  section("Mac App Store apps");
  // `mas list` right-aligns ids, so short ones come with leading spaces.
  const masApps = lines((await spin("Listing App Store apps", () => capture(["mas", "list"]))).out).map((line) =>
    line.trimStart(),
  );
  for (const [name = "", id = ""] of readFields(installFile("Masfile"))) {
    check(name, masApps.some((line) => line.startsWith(`${id} `)) || "not installed", makeFix("mas-apps"));
  }

  print();
  section("macOS defaults");
  if (!(await defaults.check())) failed(DEFAULTS_FIX);

  print();
  section("Login items");
  const loginPaths = (
    await spin("Reading login items", () =>
      capture(["osascript", "-e", 'tell application "System Events" to get the path of every login item']),
    )
  ).out;
  for (const app of readLines(installFile("Loginfile"))) {
    const label = basename(app, ".app");
    if (!isDir(app)) check(label, "app not installed", makeFix("packages"));
    else check(label, loginPaths.includes(app) || "not a login item", makeFix("login-items"));
  }

  print();
  section("Claude Code MCP servers");
  for (const [name = ""] of readFields(installFile("Mcpfile"))) {
    await probe(
      name,
      async () => (await succeeds(["claude", "mcp", "get", name])) || "not configured",
      makeFix("claude-mcp"),
    );
  }

  print();
  section("Claude Code plugins");
  const plugins = lines((await spin("Listing plugins", () => capture(["claude", "plugin", "list"]))).out);
  for (const [plugin = ""] of readFields(installFile("Pluginfile"))) {
    check(plugin, plugins.some((line) => line.endsWith(`❯ ${plugin}`)) || "not installed", makeFix("claude-plugins"));
  }

  print();
  section("Claude Code skills");
  const skillSources = readLines(installFile("Skillfile"));
  const skills = skillSources.length
    ? lines(Bun.stripANSI((await spin("Listing skills", () => capture(["npx", "--yes", "skills", "list", "-g"]))).out))
    : [];
  for (const source of skillSources) {
    check(
      source,
      skills.some((line) => line.endsWith(`Source: ${source}`)) || "not installed",
      makeFix("claude-skills"),
    );
  }

  print();
  section("asdf runtimes");
  for (const { name, version } of parseToolVersions(readText(join(DOTFILES_DIR, "runcom/.tool-versions")))) {
    await probe(
      `${name} ${version}`,
      async () => (await capture(["asdf", "list", name])).out.includes(version) || "not installed",
      makeFix("asdf-plugins"),
    );
  }

  print();
  if (fixes.size === 0) {
    success("All checks passed.");
    return true;
  }
  if (!fix) {
    error("Some checks failed. To fix, run:");
    for (const { command } of fixes.values()) info(command);
    note("Or run `dot health --fix` to run them all.");
    return false;
  }

  // Each fix is idempotent and a failing one must not strand the rest, same as `make`.
  for (const { command, apply } of fixes.values()) {
    print();
    step(command);
    await apply();
  }
  // Report what the fixes actually achieved rather than trusting their exit codes.
  print();
  step("Re-checking");
  print();
  return health();
}
