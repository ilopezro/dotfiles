import { existsSync, lstatSync, statSync } from "node:fs";
import { basename, join } from "node:path";
import * as casks from "@/commands/casks.ts";
import * as defaults from "@/commands/defaults.ts";
import { error, fail, note, pass, print, section, success } from "@/lib/colors.ts";
import { parseToolVersions, readFields, readLines, readText } from "@/lib/manifest.ts";
import { DOTFILES_DIR, expandHome, HOME, installFile } from "@/lib/paths.ts";
import { capture, has, lines, succeeds } from "@/lib/proc.ts";

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

export async function health() {
  let ok = true;
  const check = (label: string, result: true | string) => {
    if (result === true) {
      pass(label);
    } else {
      fail(`${label} (${result})`);
      ok = false;
    }
  };

  section("Symlinks");
  for (const file of [".zshrc", ".tool-versions", ".asdfrc"]) {
    check(file, isLink(join(HOME, file)) || "not linked");
  }
  for (const [src = "", dest = ""] of readFields(installFile("Linkfile"))) {
    const target = expandHome(dest);
    check(src, !isLink(target) ? "not linked" : !existsSync(target) ? "dangling link" : true);
  }

  print();
  section("Commit signing");
  const keyPath = expandHome(
    (await capture(["git", "config", "user.signingkey"])).out || `${HOME}/.ssh/id_ed25519.pub`,
  );
  if (!existsSync(keyPath)) {
    check("signing key", `no key at ${keyPath}`);
  } else {
    const key = (readLines(keyPath)[0] ?? "").split(/\s+/).slice(0, 2).join(" ");
    const signers = readText(join(DOTFILES_DIR, "config/git/allowed_signers"));
    check("key trusted in allowed_signers", signers.includes(key) || "run `make signers`");
  }

  print();
  section("Tools");
  for (const cmd of ["brew", "git", "stow", "asdf", "bun", "code", "mas"]) {
    check(cmd, has(cmd) || "not found");
  }

  print();
  section("Cask apps");
  if (!(await casks.check())) {
    ok = false;
    note("Run `dot casks repair` to fix them.");
  }
  await casks.reportExtras();

  print();
  section("Global npm tools");
  for (const pkg of readLines(installFile("Npmfile"))) {
    check(pkg, (await succeeds(["npm", "list", "-g", "--depth=0", pkg])) || "not installed");
  }

  print();
  section("Mac App Store apps");
  // `mas list` right-aligns ids, so short ones come with leading spaces.
  const masApps = lines((await capture(["mas", "list"])).out).map((line) => line.trimStart());
  for (const [name = "", id = ""] of readFields(installFile("Masfile"))) {
    check(name, masApps.some((line) => line.startsWith(`${id} `)) || "not installed");
  }

  print();
  section("macOS defaults");
  if (!(await defaults.check())) ok = false;

  print();
  section("Login items");
  const loginPaths = (
    await capture(["osascript", "-e", 'tell application "System Events" to get the path of every login item'])
  ).out;
  for (const app of readLines(installFile("Loginfile"))) {
    const label = basename(app, ".app");
    if (!isDir(app)) check(label, "app not installed");
    else check(label, loginPaths.includes(app) || "not a login item — run `make login-items`");
  }

  print();
  section("Claude Code MCP servers");
  for (const [name = ""] of readFields(installFile("Mcpfile"))) {
    check(name, (await succeeds(["claude", "mcp", "get", name])) || "not configured");
  }

  print();
  section("Claude Code plugins");
  const plugins = lines((await capture(["claude", "plugin", "list"])).out);
  for (const [plugin = ""] of readFields(installFile("Pluginfile"))) {
    check(plugin, plugins.some((line) => line.endsWith(`❯ ${plugin}`)) || "not installed");
  }

  print();
  section("Claude Code skills");
  const skillSources = readLines(installFile("Skillfile"));
  const skills = skillSources.length
    ? lines(Bun.stripANSI((await capture(["npx", "--yes", "skills", "list", "-g"])).out))
    : [];
  for (const source of skillSources) {
    check(source, skills.some((line) => line.endsWith(`Source: ${source}`)) || "not installed");
  }

  print();
  section("asdf runtimes");
  for (const { name, version } of parseToolVersions(readText(join(DOTFILES_DIR, "runcom/.tool-versions")))) {
    const installed = (await capture(["asdf", "list", name])).out;
    check(`${name} ${version}`, installed.includes(version) || "not installed");
  }

  print();
  if (ok) success("All checks passed.");
  else error("Some checks failed. Run `dot install`, `make cask-apps`, or `make link` to fix.");
}
