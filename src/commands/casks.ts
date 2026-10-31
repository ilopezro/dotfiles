// Verifies that every cask in install/Caskfile is not just recorded as installed by
// Homebrew, but that its artifacts actually exist on disk. A failed `brew upgrade` can
// delete /Applications/Foo.app while leaving the Caskroom receipt in place, so
// `brew bundle` reports the cask as up to date forever. This catches that drift.
import { existsSync, lstatSync, readdirSync, readlinkSync, rmSync } from "node:fs";
import { userInfo } from "node:os";
import { basename, join } from "node:path";
import { C, error, fail, info, note, pass, print, STDERR, section, step, success, warn } from "@/lib/colors.ts";
import { parseCaskfile, readText } from "@/lib/manifest.ts";
import { HOME, installFile } from "@/lib/paths.ts";
import { capture, lines, run, succeeds } from "@/lib/proc.ts";

export type Artifact = { kind: "app" | "bin"; value: string };

const ME = userInfo().username;

function caskfile() {
  return parseCaskfile(readText(installFile("Caskfile")));
}

// `brew list --cask` prints bare tokens, so strip any tap prefix before comparing.
async function extras() {
  const wanted = new Set(caskfile().map((cask) => cask.replace(/.*\//, "")));
  const installed = lines((await capture(["brew", "list", "--cask", "-1"])).out);
  return [...new Set(installed)].filter((cask) => !wanted.has(cask)).sort();
}

// Collects the App and Binary artifacts per cask from `brew info --cask` output.
export function parseArtifacts(text: string) {
  const result = new Map<string, Artifact[]>();
  let cask = "";
  let inArtifacts = false;
  for (const line of text.split("\n")) {
    if (line === "==> Artifacts") {
      inArtifacts = true;
      continue;
    }
    if (line.startsWith("==> ")) {
      inArtifacts = false;
      cask = line.match(/^==> (\S+?)(?: \([^)]*\))?: /)?.[1] ?? cask;
      continue;
    }
    if (!inArtifacts || !cask) continue;
    const [, value, type] = line.match(/^(.*) \((App|Binary)\)$/) ?? [];
    if (!value) continue;
    const list = result.get(cask) ?? [];
    list.push({ kind: type === "App" ? "app" : "bin", value });
    result.set(cask, list);
  }
  return result;
}

// An artifact may be written as "source -> target"; the target is what actually lands
// on disk, so that is what we check. Keep it whole rather than reducing it to a
// basename: Binary targets are often absolute paths outside the Homebrew prefix
// (docker-desktop links into /usr/local/bin), and dropping the directory made those
// casks read as broken forever no matter how often they were reinstalled.
export function installedTarget(value: string) {
  const arrow = value.lastIndexOf(" -> ");
  return arrow === -1 ? value : value.slice(arrow + 4);
}

// Homebrew moves App artifacts into place as the invoking user. An app that updates
// itself through a privileged helper (Slack does) can come back owned by root, and
// then `brew upgrade` fails with "Permission denied @ apply2files" and strands a
// backup copy in the Caskroom. The bundle and its Contents are checked rather than
// every file, which would mean walking hundreds of MB per app.
async function foreignOwner(path: string) {
  const owners = lines((await capture(["stat", "-f", "%Su", path, join(path, "Contents")])).out);
  return owners.find((owner) => owner !== ME);
}

// One status per cask: ok | missing | broken: <artifact> | owned by <user>: <app path>
async function statusOf(cask: string, artifacts: Artifact[], installed: Set<string>, brewPrefix: string) {
  if (!installed.has(cask)) return "missing";

  for (const { kind, value } of artifacts) {
    const target = installedTarget(value);
    const name = basename(target);
    if (kind === "app") {
      const path = [join("/Applications", name), join(HOME, "Applications", name)].find((p) => existsSync(p));
      if (path) {
        const owner = await foreignOwner(path);
        if (owner) return `owned by ${owner}: ${path}`;
        continue;
      }
    } else if (existsSync(target.startsWith("/") ? target : join(brewPrefix, "bin", name))) {
      continue;
    }
    return `broken: ${name}`;
  }

  return "ok";
}

async function collect() {
  const casks = caskfile();
  if (casks.length === 0) return [];

  const brewPrefix = (await capture(["brew", "--prefix"])).out;
  const installed = new Set(lines((await capture(["brew", "list", "--cask"])).out));
  const artifacts = parseArtifacts((await capture(["brew", "info", "--cask", ...casks])).out);

  const statuses = [];
  for (const cask of casks) {
    statuses.push({ cask, status: await statusOf(cask, artifacts.get(cask) ?? [], installed, brewPrefix) });
  }
  return statuses;
}

// Repairing a cask can need root: casks like docker-desktop own symlinks in
// /usr/local/bin, outside the Homebrew prefix. Homebrew removes those from a sandbox
// child with no controlling terminal, so its sudo prompt blocks forever with echo
// still on. Prime the credential cache here, on the real terminal, before any brew
// work starts.
async function ensureSudo() {
  if (await succeeds(["sudo", "-n", "true"])) return true;

  if (!process.stdin.isTTY) {
    error("dot: cask repair needs sudo, but there is no terminal to prompt on.", STDERR);
    note("Run 'sudo -v' in your shell first, then re-run: dot casks repair", STDERR);
    return false;
  }

  note("Repair needs sudo to remove symlinks outside the Homebrew prefix or reclaim root-owned apps.");
  return run(["sudo", "-v"]);
}

// Drop symlinks in the cask bin directories that point into an /Applications path
// which no longer exists. A half-finished uninstall leaves these behind, and brew
// then needs root to clear them. Only ever removes links that are already broken,
// so running it twice is a no-op.
async function pruneDanglingLinks(brewPrefix: string) {
  for (const dir of ["/usr/local/bin", "/usr/local/cli-plugins", join(brewPrefix, "bin")]) {
    let entries: string[];
    try {
      entries = readdirSync(dir);
    } catch {
      continue;
    }
    for (const entry of entries) {
      const link = join(dir, entry);
      try {
        if (!lstatSync(link).isSymbolicLink() || existsSync(link)) continue;
        if (!readlinkSync(link).includes("/Applications/")) continue;
      } catch {
        continue;
      }
      info(`removing dangling symlink ${link}`);
      try {
        rmSync(link, { force: true });
      } catch {
        await run(["sudo", "rm", "-f", link]);
      }
    }
  }
}

async function reinstall(cask: string, brewPrefix: string) {
  await pruneDanglingLinks(brewPrefix);
  if (await run(["brew", "reinstall", "--cask", cask])) return true;

  warn(`reinstall failed, forcing a clean install of ${cask}...`);
  await run(["brew", "uninstall", "--cask", "--force", cask]);
  await pruneDanglingLinks(brewPrefix);
  return run(["brew", "install", "--cask", "--force", cask]);
}

export async function check() {
  let ok = true;
  for (const { cask, status } of await collect()) {
    if (status === "ok") {
      pass(cask);
    } else {
      fail(`${cask} (${status})`);
      ok = false;
    }
  }
  return ok;
}

export async function repair() {
  // Collect first, so the whole list is known before anything is touched. Deciding
  // mid-loop means an interrupt leaves no record of what was still outstanding.
  const pending = (await collect()).filter(({ status }) => status !== "ok");

  if (pending.length === 0) {
    success("All casks healthy.");
    return true;
  }

  if (!(await ensureSudo())) return false;

  // Interrupting a cask uninstall part-way is what creates the receipt-without-app
  // state to begin with, so say plainly how to finish it.
  const onInterrupt = () => {
    print();
    print("Interrupted. Re-run `dot casks repair` to finish.");
    process.exit(130);
  };
  process.on("SIGINT", onInterrupt);
  process.on("SIGTERM", onInterrupt);

  const brewPrefix = (await capture(["brew", "--prefix"])).out;
  for (const { cask, status } of pending) {
    step(`Repairing ${cask} (${status})...`);
    if (status.startsWith("owned by ")) {
      // macOS App Management blocks changes to another app's bundle even for root,
      // so an un-granted terminal gets "Operation not permitted" here.
      const path = status.slice(status.indexOf(": ") + 2);
      if (!(await run(["sudo", "chown", "-R", ME, path]))) {
        warn(
          "chown failed. If it said 'Operation not permitted', allow your terminal under System Settings > Privacy & Security > App Management, restart it, and re-run.",
        );
      }
    } else {
      await reinstall(cask, brewPrefix);
    }
  }

  process.off("SIGINT", onInterrupt);
  process.off("SIGTERM", onInterrupt);

  print();
  step("Re-checking...");
  return check();
}

// Extras are reported, never treated as failures: a one-off install is allowed, it
// just should not go unnoticed.
export async function reportExtras() {
  const list = await extras();
  if (list.length === 0) {
    pass("no casks outside Caskfile");
    return;
  }
  for (const cask of list) warn(`${cask} (not in Caskfile)`);
  note("Add them to install/Caskfile to keep them, or run `dot prune` to uninstall them.");
}

function confirm(question: string) {
  const answer = prompt(`${C.bold}${question}${C.reset} [y/N]`) ?? "";
  return /^(y|yes)$/i.test(answer.trim());
}

// Prompts per cask by default, since every yes deletes an app. --all asks once for
// the whole list.
export async function prune(all: boolean) {
  const list = await extras();
  if (list.length === 0) {
    success("No casks outside Caskfile.");
    return true;
  }

  if (!process.stdin.isTTY) {
    error("dot: prune needs a terminal to confirm; nothing was uninstalled.", STDERR);
    return false;
  }

  section("These casks are installed but not in install/Caskfile:");
  for (const cask of list) warn(cask);
  print();

  if (all && !confirm("Uninstall all of them?")) {
    note("Nothing uninstalled.");
    return true;
  }

  for (const cask of list) {
    if (!all && !confirm(`Uninstall ${cask}?`)) {
      note(`keeping ${cask}`);
      continue;
    }
    step(`Uninstalling ${cask}...`);
    if (!(await run(["brew", "uninstall", "--cask", cask]))) fail(`failed to uninstall ${cask}`);
  }
  return true;
}
